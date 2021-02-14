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

## Contributing

See [decidim-cfg](https://github.com/codeforjapan/decidim-cfj).

## License

The engine is available as open source under the terms of the [AGPL3](https://opensource.org/licenses/AGPL-3.0).
