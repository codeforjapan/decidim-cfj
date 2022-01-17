# Change Log
## [v0.23.5-2021-11-08](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.5-2021-11-08)
### Fixed
- Fix messages endorsement in JA [#299](https://github.com/codeforjapan/decidim-cfj/pull/299)

## [v0.23.5-2021-10-31](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.5-2021-10-31)

### Added
- chore: add kinesis firehose for waf log [#283](https://github.com/codeforjapan/decidim-cfj/pull/283)

### Fixed
- Fix limit for Decidim::Comments::SortedCommments [#298](https://github.com/codeforjapan/decidim-cfj/pull/298)
- Update changelog & hotfix release [#297](https://github.com/codeforjapan/decidim-cfj/pull/297)

## [v0.23.5-2021-10-27](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.5-2021-10-27)

### Added
- chore: add cloud formation of waf [#280](https://github.com/codeforjapan/decidim-cfj/pull/280)
- Support Decidim::DecidimAwesome [#1](https://github.com/ayuki-joto/decidim-cfj/pull/1)

### Changed
- Feature/update decidim v0.23.5 [#223](https://github.com/codeforjapan/decidim-cfj/pull/223)
- Fix message of mark_all_as_read [#284](https://github.com/codeforjapan/decidim-cfj/pull/284)
- upgrade instance type to t2.medium [#287](https://github.com/codeforjapan/decidim-cfj/pull/287)
- Update production environment name [#291](https://github.com/codeforjapan/decidim-cfj/pull/291)
- chore: fix cloud front CustomOrigin timeout 30s -> 60s [#295](https://github.com/codeforjapan/decidim-cfj/pull/295)

### Fixed
- fix: delete public docker volume for cache [#275](https://github.com/codeforjapan/decidim-cfj/pull/275)
- Optimize queries in Decidim::ResourceVersionsHelper.resource_version [#289](https://github.com/codeforjapan/decidim-cfj/pull/289)
- Fix translation versions.resource_version.of_version [#290](https://github.com/codeforjapan/decidim-cfj/pull/290)
- Add comments about height/width of the image instead of file size [#293](https://github.com/codeforjapan/decidim-cfj/pull/293)
- Use 円 instead of YEN mark [#294](https://github.com/codeforjapan/decidim-cfj/pull/294)
- Support HtmlEditButton for Quill editor in DecidimAwesome [#2](https://github.com/ayuki-joto/decidim-cfj/pull/2)
- Show limited number of comments, add "show all comments" button [#4](https://github.com/ayuki-joto/decidim-cfj/pull/4), [#5](https://github.com/ayuki-joto/decidim-cfj/pull/5)
- Fix show comments [#6](https://github.com/ayuki-joto/decidim-cfj/pull/6)
- Do not hide the button while loading comments [#7](https://github.com/ayuki-joto/decidim-cfj/pull/7)


### Developer improvements
- docs: move markdown document to docs [#273](https://github.com/codeforjapan/decidim-cfj/pull/273)
- fix: change cache policy name to by environment [#277](https://github.com/codeforjapan/decidim-cfj/pull/277)
- chore: remove glacier life cycle on cloud front log s3 [#282](https://github.com/codeforjapan/decidim-cfj/pull/282)


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
