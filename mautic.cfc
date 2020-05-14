/**
* Mautic CFML
* Copyright 2020  Matthew J. Clemente, John Berquist
* Licensed under MIT (https://mit-license.org)
*/
component displayname="Mautic CFML"  {

  variables._mauticcfml_version = '0.0.0'; 

  public any function init(
    string username = '',
    string password = '',
    string apiEndpoint = '',
    boolean includeRaw = false,
    numeric httpTimeout = 50 
  ) {

    if( !len( apiEndpoint ) ){
      throw( message = "API endpoint not provided", detail = "Provide your Mautic installation API endpoint in the format: https://your-mautic.com/api" );
    }

    structAppend( variables, arguments );

    //map sensitive args to env variables or java system props
    var secrets = {
      'username': 'MAUTIC_USERNAME',
      'password': 'MAUTIC_PASSWORD',
      'apiEndpoint': 'MAUTIC_APIENDPOINT'
    };
    var system = createObject( 'java', 'java.lang.System' );

    for ( var key in secrets ) {
      //arguments are top priority
      if ( variables[ key ].len() ) {
        continue;
      }

      //check environment variables
      var envValue = system.getenv( secrets[ key ] );
      if ( !isNull( envValue ) && envValue.len() ) {
        variables[ key ] = envValue;
        continue;
      }

      //check java system properties
      var propValue = system.getProperty( secrets[ key ] );
      if ( !isNull( propValue ) && propValue.len() ) {
        variables[ key ] = propValue;
      }
    }

    //declare file fields to be handled via multipart/form-data **Important** this is not applicable if payload is application/json
    variables.fileFields = [ 'file' ];

    return this;
  }

  /**
  * https://developer.mautic.org/#create-asset
  * @hint Create a new asset. 
  * @storageLocation can be either `local` or `remote`
  */
  public struct function createAsset( string title, string storageLocation, string file ) {
    var payload = {
      'title': title,
      'storageLocation': storageLocation,
      'file': file
    };
    return apiCall( 'POST', '/assets/new', {}, payload );
  }

  /**
  * https://developer.mautic.org/#edit-asset
  * @hint Edit an asset
  * @data properties of the asset
  * @createIfNotFound creates a new asset if the id is not found. If you're using this, you need to include all the required fields in order to create an asset
  */
  public struct function editAsset( string id, struct data, boolean createIfNotFound = false ) {
    if( createIfNotFound ){
      return apiCall( 'PUT', '/assets/#id#/edit', {}, data );
    } else {
      return apiCall( 'PATCH', '/assets/#id#/edit', {}, data );
    }
  }

  /**
  * https://developer.mautic.org/#get-asset
  * @hint Get an individual asset by id
  */
  public struct function getAsset( string id ) {
    return apiCall( 'GET', '/assets/#id#' );
  }

  /**
  * https://developer.mautic.org/#list-assets
  * @hint List assets
  */
  public struct function listAssets() {
    return apiCall( 'GET', '/assets' );
  }

  /**
  * https://developer.mautic.org/#delete-asset
  * @hint Delete an asset by id
  */
  public struct function deleteAsset( string id ) {
    return apiCall( 'DELETE', '/assets/#id#/delete' );
  }

  /**
  * https://developer.mautic.org/#create-file
  * @hint Creates a file.
  * @directory should be either `images` or `assets`
  */
  public struct function createFile( any file, directory = 'images', subdir = '' ) {
    var params = {
      'subdir': subdir
    };
    var payload = {
      'file': file
    }
    return apiCall( 'POST', '/files/#directory#/new', params, payload, { 'Content-Type' : 'multipart/form-data' } );
  }

  /**
  * https://developer.mautic.org/#get-list-of-files
  * @hint List either image or asset files
  * @directory should be either `images` or `assets`
  */
  public struct function listFiles( directory = 'images', subdir = '' ) {
    var params = {
      'subdir': subdir
    };
    return apiCall( 'GET', '/files/#directory#', params );
  }

  /**
  * @hint List image files. Delagates to `listFiles()`
  */
  public struct function listImageFiles( subdir = '' ) {
    return listFiles( directory = 'images', subdir = subdir );
  }

  /**
  * @hint List asset files. Delagates to `listFiles()`
  */
  public struct function listAssetFiles( subdir = '' ) {
    return listFiles( directory = 'assets', subdir = subdir );
  }

  /**
  * https://developer.mautic.org/?php#delete-file
  * @hint Delete a file
  */
  public struct function deleteFile( string filename, directory = 'images', subdir = '' ) {
    var params = {
      'subdir': subdir
    };
    return apiCall( 'DELETE', '/files/#directory#/#filename#/delete', params );
  }

  /**
  * https://developer.mautic.org/#get-self-user
  * @hint Get the user making the request
  */
  public struct function getSelfUser() {
    return apiCall( 'GET', '/users/self' );
  }


  // PRIVATE FUNCTIONS
  private struct function apiCall(
    required string httpMethod,
    required string path,
    struct queryParams = { },
    any payload = '',
    struct headers = { } 
  ) {

    var fullApiPath = variables.apiEndpoint & path;
    var requestHeaders = getBaseHttpHeaders();
    requestHeaders.append( headers, true );

    var requestStart = getTickCount();
    var apiResponse = makeHttpRequest( httpMethod = httpMethod, path = fullApiPath, queryParams = queryParams, headers = requestHeaders, payload = payload );

    var result = {
      'responseTime' = getTickCount() - requestStart,
      'statusCode' = listFirst( apiResponse.statuscode, " " ),
      'statusText' = listRest( apiResponse.statuscode, " " ),
      'headers' = apiResponse.responseheader
    };

    var parsedFileContent = {};

    // Handle response based on mimetype
    var mimeType = apiResponse.mimetype ?: requestHeaders[ 'Content-Type' ];

    if ( mimeType == 'application/json' && isJson( apiResponse.fileContent ) ) {
      parsedFileContent = deserializeJSON( apiResponse.fileContent );
    } else if ( mimeType.listLast( '/' ) == 'xml' && isXml( apiResponse.fileContent ) ) {
      parsedFileContent = xmlToStruct( apiResponse.fileContent );
    } else {
      parsedFileContent = apiResponse.fileContent;
    }

    //can be customized by API integration for how errors are returned
    //if ( result.statusCode >= 400 ) {}

    //stored in data, because some responses are arrays and others are structs
    result[ 'data' ] = parsedFileContent;

    if ( variables.includeRaw ) {
      result[ 'raw' ] = {
        'method' : ucase( httpMethod ),
        'path' : fullApiPath,
        'params' : parseQueryParams( queryParams ),
        'payload' : parseBody( payload ),
        'response' : apiResponse.fileContent
      };
    }

    return result;
  }

  private struct function getBaseHttpHeaders() {
    return {
      'Accept' : 'application/json',
      'Content-Type' : 'application/json',
      'User-Agent' : 'Mautic CFML/#variables._mauticcfml_version# (ColdFusion)'
    };
  }

  private any function makeHttpRequest(
    required string httpMethod,
    required string path,
    struct queryParams = { },
    struct headers = { },
    any payload = ''
  ) {
    var result = '';

    var fullPath = path & ( !queryParams.isEmpty()
      ? ( '?' & parseQueryParams( queryParams, false ) )
      : '' );

    cfhttp( url = fullPath, method = httpMethod, username = variables.username, password = variables.password, result = 'result', timeout = variables.httpTimeout ) {

      if ( isJsonPayload( headers ) ) {

        var requestPayload = parseBody( payload );
        if ( isJSON( requestPayload ) ) {
          cfhttpparam( type = "body", value = requestPayload );
        }

      } else if ( isFormPayload( headers ) ) {

        headers.delete( 'Content-Type' ); //Content Type added automatically by cfhttppparam

        for ( var param in payload ) {
          if ( !variables.fileFields.contains( param ) ) {
            cfhttpparam( type = 'formfield', name = param, value = payload[ param ] );
          } else {
            cfhttpparam( type = 'file', name = param, file = payload[ param ] );
          }
        }

      }

      //handled last, to account for possible Content-Type header correction for forms
      var requestHeaders = parseHeaders( headers );
      for ( var header in requestHeaders ) {
        cfhttpparam( type = "header", name = header.name, value = header.value );
      }

    }
    return result;
  }

  /**
  * @hint convert the headers from a struct to an array
  */
  private array function parseHeaders( required struct headers ) {
    var sortedKeyArray = headers.keyArray();
    sortedKeyArray.sort( 'textnocase' );
    var processedHeaders = sortedKeyArray.map(
      function( key ) {
        return { name: key, value: trim( headers[ key ] ) };
      }
    );
    return processedHeaders;
  }

  /**
  * @hint converts the queryparam struct to a string, with optional encoding and the possibility for empty values being pass through as well
  */
  private string function parseQueryParams( required struct queryParams, boolean encodeQueryParams = true, boolean includeEmptyValues = true ) {
    var sortedKeyArray = queryParams.keyArray();
    sortedKeyArray.sort( 'text' );

    var queryString = sortedKeyArray.reduce(
      function( queryString, queryParamKey ) {
        var encodedKey = encodeQueryParams
          ? encodeUrl( queryParamKey )
          : queryParamKey;
        if ( !isArray( queryParams[ queryParamKey ] ) ) {
          var encodedValue = encodeQueryParams && len( queryParams[ queryParamKey ] )
            ? encodeUrl( queryParams[ queryParamKey ] )
            : queryParams[ queryParamKey ];
        } else {
          var encodedValue = encodeQueryParams && ArrayLen( queryParams[ queryParamKey ] )
            ?  encodeUrl( serializeJSON( queryParams[ queryParamKey ] ) )
            : queryParams[ queryParamKey ].toList();
          }
        return queryString.listAppend( encodedKey & ( includeEmptyValues || len( encodedValue ) ? ( '=' & encodedValue ) : '' ), '&' );
      }, ''
    );

    return queryString.len() ? queryString : '';
  }

  private string function parseBody( required any body ) {
    if ( isStruct( body ) || isArray( body ) ) {
      return serializeJson( body );
    } else if ( isJson( body ) ) {
      return body;
    } else {
      return '';
    }
  }

  private string function encodeUrl( required string str, boolean encodeSlash = true ) {
    var result = replacelist( urlEncodedFormat( str, 'utf-8' ), '%2D,%2E,%5F,%7E', '-,.,_,~' );
    if ( !encodeSlash ) {
      result = replace( result, '%2F', '/', 'all' );
    }
    return result;
  }

  /**
  * @hint helper to determine if body should be sent as JSON
  */
  private boolean function isJsonPayload( required struct headers ) {
    return headers[ 'Content-Type' ] == 'application/json';
  }

  /**
  * @hint helper to determine if body should be sent as form params
  */
  private boolean function isFormPayload( required struct headers ) {
    return arrayContains( [ 'application/x-www-form-urlencoded', 'multipart/form-data' ], headers[ 'Content-Type' ] );
  }

  /**
  *
  * Based on an (old) blog post and UDF from Raymond Camden
  * https://www.raymondcamden.com/2012/01/04/Converting-XML-to-JSON-My-exploration-into-madness/
  *
  */
  private struct function xmlToStruct( required any x ) {

    if ( isSimpleValue( x ) && isXml( x ) ) {
      x = xmlParse( x );
    }

    var s = {};

    if ( xmlGetNodeType( x ) == "DOCUMENT_NODE" ) {
      s[ structKeyList( x ) ] = xmlToStruct( x[ structKeyList( x ) ] );
    }

    if ( structKeyExists( x, "xmlAttributes" ) && !structIsEmpty( x.xmlAttributes ) ) {
      s.attributes = {};
      for ( var item in x.xmlAttributes ) {
        s.attributes[ item ] = x.xmlAttributes[ item ];
      }
    }

    if ( structKeyExists( x, 'xmlText' ) && x.xmlText.trim().len() ) {
      s.value = x.xmlText;
    }

    if ( structKeyExists( x, "xmlChildren" ) ) {

      for ( var xmlChild in x.xmlChildren ) {
        if ( structKeyExists( s, xmlChild.xmlname ) ) {

          if ( !isArray( s[ xmlChild.xmlname ] ) ) {
            var temp = s[ xmlChild.xmlname ];
            s[ xmlChild.xmlname ] = [ temp ];
          }

          arrayAppend( s[ xmlChild.xmlname ], xmlToStruct( xmlChild ) );

        } else {

          if ( structKeyExists( xmlChild, "xmlChildren" ) && arrayLen( xmlChild.xmlChildren ) ) {
              s[ xmlChild.xmlName ] = xmlToStruct( xmlChild );
          } else if ( structKeyExists( xmlChild, "xmlAttributes" ) && !structIsEmpty( xmlChild.xmlAttributes ) ) {
            s[ xmlChild.xmlName ] = xmlToStruct( xmlChild );
          } else {
            s[ xmlChild.xmlName ] = xmlChild.xmlText;
          }

        }

      }
    }

    return s;
  }

}