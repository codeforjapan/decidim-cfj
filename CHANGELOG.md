# Change Log
## [v0.24.3-2022-06-01](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.5-2022-06-01)

### Added
- Add Decidim::TermCustomer [#355](https://github.com/codeforjapan/decidim-cfj/pull/355)
- add rake task [#383](https://github.com/codeforjapan/decidim-cfj/pull/383)

### Changed
- Use Engine for user_extension modulee [#229](https://github.com/codeforjapan/decidim-cfj/pull/229)

- ### Fixed
Fix quill-html-edit-button (#377) [#379](https://github.com/codeforjapan/decidim-cfj/pull/379)

## [v0.24.3-2022-04-14](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.5-2022-04-14)

### Added
- Add JA locale data for verification [#367](https://github.com/codeforjapan/decidim-cfj/pull/367)

### Fixed
- Fix AuthorizeUser; "Fix verification report with multitenants" [#366](https://github.com/codeforjapan/decidim-cfj/pull/366)

## [v0.24.3-2022-04-11](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.5-2022-04-11)

### Fixed
- Fix error in /debates/versions [#361](https://github.com/codeforjapan/decidim-cfj/pull/361)
- Fix undefined local variable or method component error [#363](https://github.com/codeforjapan/decidim-cfj/pull/363)

## [v0.24.3-2022-04-08](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.5-2022-04-08)

### Added
- Feedback from decidim/decidim v0.24.3 [#329](https://github.com/codeforjapan/decidim-cfj/pull/329)

### Fixed
- Reset Decidim::ApplicationUploader#validate_inside_organization to original definition [#324](https://github.com/codeforjapan/decidim-cfj/pull/324)
- Fixed not to be displayed when the history is too large [#359](https://github.com/codeforjapan/decidim-cfj/pull/359)
- Fix GitHub Actions: move env, no need bundler  [#360](https://github.com/codeforjapan/decidim-cfj/pull/360)

### Changed
- update decidim v0.24.3  [#312](https://github.com/codeforjapan/decidim-cfj/pull/312)
- update production environment name  [#356](https://github.com/codeforjapan/decidim-cfj/pull/356)

## [v0.23.5-2022-03-06](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.5-2022-03-06)

### Fixed
- chore: disabled SQLi_BODY rule on waf for uploading image [#343](https://github.com/codeforjapan/decidim-cfj/pull/343)
- Fix translation: Is visible duplicate  [#349](https://github.com/codeforjapan/decidim-cfj/pull/349)

### Changed
- Allow to change DB name in dev/test [#342](https://github.com/codeforjapan/decidim-cfj/pull/342)
- use aws ses ap-northeast-1 region [#346](https://github.com/codeforjapan/decidim-cfj/pull/346)
- Update newrelic_rpm gem [#347](https://github.com/codeforjapan/decidim-cfj/pull/347)
- Remove search box [#348](https://github.com/codeforjapan/decidim-cfj/pull/348)

## [v0.23.5-2022-02-22](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.5-2022-02-22)

### Added
- add new script [#318](https://github.com/codeforjapan/decidim-cfj/pull/318)
- Add UPGRADE.md [#326](https://github.com/codeforjapan/decidim-cfj/pull/326)

### Fixed
- Fixed #24 in original Decidim [#328](https://github.com/codeforjapan/decidim-cfj/pull/328)
- Redirect https://www.diycities.jp/ to Metadecidim Japan [#338](https://github.com/codeforjapan/decidim-cfj/pull/338)

### Changed
- Reset Decidim::ApplicationUploader#validate_inside_organization to original definition [#324](https://github.com/codeforjapan/decidim-cfj/pull/324)
- Update docs/UPGRADE.md [#330](https://github.com/codeforjapan/decidim-cfj/pull/330)
- Add CookieOrderable; store proposals orders in cookies [#331](https://github.com/codeforjapan/decidim-cfj/pull/331)
- Improved input form; year of birth and name (added input restrictions and input support) [#335](https://github.com/codeforjapan/decidim-cfj/pull/335)
- Appropriate line breaks for long comments (alphabet, etc.) [#337](https://github.com/codeforjapan/decidim-cfj/pull/337)

## [v0.23.5-2022-01-17](https://github.com/codeforjapan/decidim-cfj/releases/tag/v0.23.5-2022-01-17)

### Fixed
- Fix [#304](https://github.com/codeforjapan/decidim-cfj/issues/304); ignore seeds of DecidimAwesome [#305](https://github.com/codeforjapan/decidim-cfj/pull/305)
- Fix db:seed in docker [#306](https://github.com/codeforjapan/decidim-cfj/pull/306)
- Fix Translation [#313](https://github.com/codeforjapan/decidim-cfj/pull/313)
- Updated translation file for Decidim Awesome [#315](https://github.com/codeforjapan/decidim-cfj/pull/315)
- fix url & remove OriginPath [#321](https://github.com/codeforjapan/decidim-cfj/pull/321)

### Changed
- Extended CloudWatch application log retention period[#308](https://github.com/codeforjapan/decidim-cfj/pull/308)
- chore: enabled AWSManagedRulesCommonRuleSet on AWS WAF [#314](https://github.com/codeforjapan/decidim-cfj/pull/314)

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
