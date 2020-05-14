# Mautic CFML
A CFML wrapper for the [Mautic API](https://developer.mautic.org/#rest-api), giving you the ability to interact with your Mautic installation for marketing campaign management. To that end, you'll need a Mautic installation in order to use this.

*Feel free to use the issue tracker to report bugs or suggest improvements!*

I began putting this together at the request of another developer using Mautic. Right now it's not close to complete - it's just mean to be a starting point, if people are interested in working with Mautic via CFML.

### Acknowledgements

This project builds on a CFML API framework built by [jcberquist](https://github.com/jcberquist). Consequently, it is also licensed under the terms of the MIT license.

## Table of Contents

- [Quick Start](#quick-start)
  - [Authentication and Initialization](#authentication-and-initialization)
- [`Mautic CFML` Reference Manual](#reference-manual)
- [Questions](#questions)
- [Contributing](#contributing)

## Quick Start

Here's a basic example of using the component to list assets.

```cfc
mautic = new path.to.mauticcfml.mautic( username = 'xxx', password = 'xxx', apiEndpoint = 'https://your-mautic.com/api' );

mautic.listAssets();
```

### Authentication and Initialization

You'll need to make sure your Mautic installation supports Basic Authentication, as explained [here](https://developer.mautic.org/?php#basic-authentication). Once set up, you can use an account username and password to authenticate and interact with the API.

The component is initialized using your username, password, and Mautic API endpoint. These can be provided to the component directly, as in the [Quick Start](#quick-start) example, or via environment variables, using the following names:

- `MAUTIC_USERNAME`
- `MAUTIC_PASSWORD`
- `MAUTIC_APIENDPOINT`

This API wrapper only needs to be initialized once, so your dependency injection framework should use it as a singleton, or you can store it in the application scope.

## Reference Manual

The [Mautic API documentation](https://developer.mautic.org/#rest-api) certainly has some holes, but it's still the best place to examine how these calls are supposed to execute, and what to expect in the responses.

#### `createAsset( string title, string storageLocation, string file )`
Create a new asset.

#### `editAsset( string id, struct data, boolean createIfNotFound = false )`
Edit an asset. The `data` argument contains the properties of the asset. The `createIfNotFound` argument creates a new asset if the `id` is not found. If you're using this, you need to include all the required fields in order to create an asset.

#### `getAsset( string id )`
Get an individual asset by id.

#### `listAssets()`
List assets.

#### `deleteAsset( string id )`
Delete an asset by id.

#### `createFile( any file, directory = 'images', subdir = '' )`
Creates a file. The `directory` argument should be either `images` or `assets`.

#### `listFiles( directory = 'images', subdir = '' )`
List either image or asset files. The `directory` argument should be either `images` or `assets`.

#### `listImageFiles( subdir = '' )`
List image files. Delagates to `listFiles()`.

#### `listAssetFiles( subdir = '' )`
List asset files. Delagates to `listFiles()`

#### `deleteFile( string filename, directory = 'images', subdir = '' )`
Delete a file.

#### `getSelfUser()`
Get the user making the request.

---

# Questions
For questions that aren't about bugs, feel free to hit me up on the [CFML Slack Channel](http://cfml-slack.herokuapp.com); I'm @mjclemente. You'll likely get a much faster response than creating an issue here.

# Contributing
:+1::tada: First off, thanks for taking the time to contribute! :tada::+1:

Before putting the work into creating a PR, I'd appreciate it if you opened an issue. That way we can discuss the best way to implement changes/features, before work is done.

Changes should be submitted as Pull Requests on the `develop` branch.