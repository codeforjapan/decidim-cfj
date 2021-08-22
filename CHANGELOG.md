# Change Log

## [v0.23.0-2021-08-07-01](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.0-2021-08-07-01)

### Fixed
- Fix locale file: decidim.errors.not_found.content_doesnt_exist [#262](https://github.com/codeforjapan/decidim-cfj/pull/262)
- Fix #268; add locale for debate_closed [#269](https://github.com/codeforjapan/decidim-cfj/pull/269)
- Fix fallbacks of i18n; use both :ja and :en [#270](https://github.com/codeforjapan/decidim-cfj/pull/270)

### Developer improvements
- fix typo decidem -> decidim on NEW_RELIC_APP_NAME [#248](https://github.com/codeforjapan/decidim-cfj/pull/248)
- enabled spot instance on staging environment [#251](https://github.com/codeforjapan/decidim-cfj/pull/251)
- add VPC & subnets Cloud Formation & INFRA.md [#249](https://github.com/codeforjapan/decidim-cfj/pull/249)
- add environment variable by SSM on ebextensions [#245](https://github.com/codeforjapan/decidim-cfj/pull/245)
- Turn off New Relic except production [#258](https://github.com/codeforjapan/decidim-cfj/pull/258)
- change auto scale trigger to Average from Maximum [#265](https://github.com/codeforjapan/decidim-cfj/pull/265)

## [v0.23.0-2021-07-28](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.0-2021-07-28)

### Developer improvements
- Update robots txt [#266](https://github.com/codeforjapan/decidim-cfj/pull/266)

## [v0.23.0-2021-06-22](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.0-2021-06-22)

### Developer improvements

- update ecr lifecycle policy to expire old tag [#243](https://github.com/codeforjapan/decidim-cfj/pull/243)
- enabled auto eb platform update on staging [#242](https://github.com/codeforjapan/decidim-cfj/pull/242)
- decrease sidekiq worker 6 -> 3 [#244](https://github.com/codeforjapan/decidim-cfj/pull/244)
- add sidkiq&nginx docker image on eb [#235](https://github.com/codeforjapan/decidim-cfj/pull/235)
- Add Changelog (CHANGELOG.md) [#238](https://github.com/codeforjapan/decidim-cfj/pull/238)

## [v0.23.0-2021-5-31](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.0-2021-5-31)

### Fixed

- Fix locale file of proposals [#233](https://github.com/codeforjapan/decidim-cfj/issues/233)

## [v0.23.0-2021-5-24](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.0-2021-5-24)

### Developer improvements

- production deploy by GitHub Actions [#232](https://github.com/codeforjapan/decidim-cfj/pull/232)
