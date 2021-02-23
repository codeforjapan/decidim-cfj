# Decidim::UserExtension

The `Decidim::UserExtension` module extends the Decidim User model (`Decidim::User`) by adding personal information such as real name and address as attributes.

## Usage

`Decidim::UserExtension` module is a Rails Engnine.
When added to the Gemfile of a Decidim application, `Decidim::User` of that application can be extended.

You can set whether to apply it or not for each organization. The configuration is done in the system panel.

## Installation

Copy `decidim-user_extension` into your application's root.

And add this line to your application's Gemfile:

```ruby
gem 'decidim-user_extension', path: 'decidim-user_extension'
```

And then execute:
```bash
$ bundle
```

## How it works

### How to store extended attributes

Since extended attributes are personal information, they are expected to be managed more strictly than normal registration data.

Decidim has [Authorization and Verification](https://github.com/decidim/decidim/blob/develop/decidim-verifications/README.md) module, which is used to provide voting functions only to users who have been verified.
For this module, it is possible to register a personal number that is required for verification.

`Decidim::UserExtension` uses this feature to store extended attributes as metadata in Authorization. Administrators are allowed to view this metadata, but when they do, they are logged in an audit log so that records of which administrator viewed which user's extended attributes can be checked on the administrator dashboard.

### When changing the settings of a running service

In general, it is not expected to take or not take extended attributes after the service is running. You should configure the settings before the service is running.

However, it is possible that you may want to change the settings of the service while it is running. In that case, the behavior will be as follows.

* If the setting is disabled after the service starts running

The collected attribute information will remain in the Authorization table.

When a user unsubscribes from the service, the attribute information will be deleted at the same time as the user information is deleted.

* If the setting is enabled after the service is running

Extended attributes are required when registering a new participant. The input items of them will appear on the new registration form.

If you are already a participant, you will be redirected to the Change User Profile page after logging in. Until you set the extended attributes there, you will not be able to use any services that require login.


## Contributing

See [decidim-cfg](https://github.com/codeforjapan/decidim-cfj).

## License

The engine is available as open source under the terms of the [AGPL3](https://opensource.org/licenses/AGPL-3.0).
