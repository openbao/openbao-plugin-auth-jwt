# OpenBao Plugin: JWT Auth Backend

This is a standalone backend plugin for use with [OpenBao](https://openbao.org/).
This plugin allows for JWTs (including OIDC tokens) to authenticate with OpenBao.

**Please note**: We take OpenBao's security and our users' trust very seriously. If you believe you have found a security issue in OpenBao, _please responsibly disclose_ by contacting us at [openbao-security@lists.lfedge.org](mailto:openbao-security@lists.lfedge.org).

## Quick Links
    - OpenBao Website: https://openbao.org/
    - JWT Auth Docs: https://openbao.org/docs/auth/jwt
    - Main Project Github: https://www.github.com/openbao/openbao

## Getting Started

This is an [OpenBao plugin](https://openbao.org/docs/plugins)
and is meant to work with OpenBao. This guide assumes you have already installed OpenBao
and have a basic understanding of how OpenBao works.

To learn specifically about how plugins work, see documentation on [OpenBao plugins](https://openbao.org/docs/plugins).

## Usage

Please see [documentation for the plugin](https://openbao.org/docs/auth/jwt)
on the OpenBao website.

This plugin is currently built into OpenBao and by default is accessed
at `auth/jwt`. To enable this in a running OpenBao server:

```sh
$ bao auth enable jwt
Successfully enabled 'jwt' at 'jwt'!
```

To see all the supported paths, see the [JWT auth backend docs](https://openbao.org/docs/auth/jwt).

## Developing

If you wish to work on this plugin, you'll first need
[Go](https://www.golang.org) installed on your machine.

For local dev first make sure Go is properly installed, including
setting up a [GOPATH](https://golang.org/doc/code.html#GOPATH).
Next, clone this repository into
`$GOPATH/src/github.com/openbao/openbao-plugin-auth-jwt`.
You can then download any required build tools by bootstrapping your
environment:

```sh
$ make bootstrap
```

To compile a development version of this plugin, run `make` or `make dev`.
This will put the plugin binary in the `bin` and `$GOPATH/bin` folders. `dev`
mode will only generate the binary for your platform and is faster:

```sh
$ make
$ make dev
```

Put the plugin binary into a location of your choice. This directory
will be specified as the [`plugin_directory`](https://openbao.org/docs/configuration#plugin_directory)
in the OpenBao config used to start the server.

```hcl
plugin_directory = "path/to/plugin/directory"
```

Start an OpenBao server with this config file:
```sh
$ bao server -config=path/to/config.hcl ...
...
```

Once the server is started, register the plugin in the OpenBao server's [plugin catalog](https://openbao.org/docs/plugins/plugin-architecture#plugin-catalog):

```sh

$ bao plugin register \
      -sha256=<SHA256 Hex value of the plugin binary> \
      -command="openbao-plugin-auth-jwt" \
      auth \
      jwt
...
Success! Data written to: sys/plugins/catalog/jwt
```

Note you should generate a new sha256 checksum if you have made changes
to the plugin. Example using openssl:

```sh
openssl dgst -sha256 $GOPATH/openbao-plugin-auth-jwt
...
SHA256(.../go/bin/openbao-plugin-auth-jwt)= 896c13c0f5305daed381952a128322e02bc28a57d0c862a78cbc2ea66e8c6fa1
```

Enable the auth plugin backend using the JWT auth plugin:

```sh
$ bao auth enable -plugin-name='jwt' plugin
...

Successfully enabled 'plugin' at 'jwt'!
```

### Provider-specific handling

Provider-specific handling can be added by writing an object that conforms to
one or more interfaces in [provider_config.go](provider_config.go). Some
interfaces will be required, like [CustomProvider](provider_config.go), and
others will be invoked if present during the login process (e.g. GroupsFetcher).
The interfaces themselves will be small (usually a single method) as it is
expected that the parts of the login that need specialization will be different
per provider. This pattern allows us to start with a minimal set and add
interfaces as necessary.

If a custom provider is configured on the backend object and satisfies a given
interface, the interface will be used during the relevant part of the login
flow. e.g. after an ID token has been received, the custom provider's
UserInfoFetcher interface will be used, if present, to fetch and merge
additional identity data.

The custom handlers will be standalone objects defined in their own file (one
per provider). They'll be part of the main jwtauth package to avoid potential
circular import issues.

### Tests

If you are developing this plugin and want to verify it is still
functioning (and you haven't broken anything else), we recommend
running the tests.

To run the tests, invoke `make test`:

```sh
$ make test
```

You can also specify a `TESTARGS` variable to filter tests like so:

```sh
$ make test TESTARGS='--run=TestConfig'
```

Additionally, there are some BATs tests in the `tests` dir.

#### Prerequisites

- [Install Bats Core](https://bats-core.readthedocs.io/en/stable/installation.html#homebrew)
- Docker or a bao binary in the `tests` directory.

#### Setup

- [Configure an OIDC provider](https://openbao.org/docs/auth/jwt/oidc-providers/)
- Save and export the following values to your shell:
  - `CLIENT_ID`
  - `CLIENT_SECRET`
  - `ISSUER`
- Export `BAO_IMAGE` to test the image of your choice or place a bao binary
  in the `tests` directory.

#### Logs

Bao logs will be written to `BAO_OUTFILE`. BATs test logs will be written to
`SETUP_TEARDOWN_OUTFILE`.

#### Run Bats tests

```
# export env vars
export CLIENT_ID="12345"
export CLIENT_SECRET="6789"
export ISSUER="my-issuer-url"

# run tests
cd tests/
./test.bats
```
