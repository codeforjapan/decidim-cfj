#!/bin/bash

# 加古川市本番サーバから GraphQL でデータを取り出し、CSVファイルに整形するプログラム

cd `dirname $0`
OUT_DIR=../tmp/data

# remove data file if it exists
if [ `ls $OUT_DIR/ | wc -l` -gt 0 ] ; then
  rm $OUT_DIR/*
fi

# download data from GraphQL
datafile=$OUT_DIR/export
echo "importing data from server and saving to $datafile"
curl 'https://kakogawa.diycities.jp/api/' -H 'Accept-Encoding: gzip, deflate, br' -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'Connection: keep-alive' -H 'DNT: 1' -H 'Origin: file://' --data-binary '{"query":"# Write your query or mutation here\nquery {\n  participatoryProcesses {\n    id\n    title {\n      translations {\n        locale\n        text\n      }\n    }\n    components {\n      id\n      name {\n        translation(locale: \"ja\")\n      }\n      ... on Debates {\n        debates {\n          edges {\n            node {\n              id\n              title {\n                translation(locale: \"ja\")\n              }\n              totalCommentsCount\n              comments {\n                createdAt\n                id\n                author {\n                  id\n                  name\n                }\n                body\n                comments{\n                  createdAt\n                  id\n                  author {\n                    id\n                    name\n                  }\n                  body\n                  comments{\n                    createdAt\n                    id\n                    author{\n                      id\n                      name\n                    }\n                    body\n                    comments{\n                      createdAt\n                      id\n                      author{\n                        id\n                        name\n                      }\n                      body\n                      comments{\n                        createdAt\n                        id\n                        author{\n                          id\n                          name\n                        }\n                        body\n                      }\n                    }\n                  }\n                }\n              }\n            }\n          }\n        }\n      }\n    }\n  }\n  decidim {\n    version\n  }\n}\n"}' --compressed > $datafile

# read components
themes=`cat $datafile | jq -c -r '.data.participatoryProcesses[].components[] | [.id, .name.translation] | @sh'`
IFS=$'\n'
for item in $themes ; do
  echo '----'
  item_id=`echo $item | cut -d ' ' -f 1`
  item_id=${item_id//\'/}
  theme_title=`echo $item | cut -d ' ' -f 2`
  echo $theme_title
  # read debates
  debates=`cat $datafile | jq -c -r --arg cid $item_id '.data.participatoryProcesses[].components[] | select(.id == $cid) | .debates?.edges[]?.node  | [.id, .title.translation ] | @sh'`
  for debate in $debates ; do
    debate_id=`echo $debate | cut -d ' ' -f 1`
    debate_id=${debate_id//\'/}
    debate_title=`echo $debate | cut -d ' ' -f2 `
    outfile=$OUT_DIR/$item_id-$debate_id.csv
    echo '  '$debate_title
    echo "  creating.. $outfile"
    # create CSV files
    echo $debate_title > $outfile
    cat $datafile | jq -c -r --arg cid $item_id --arg did $debate_id '.data.participatoryProcesses[].components[] | select(.id == $cid) | .debates?.edges[]?.node  | select(.id == $did) | recurse | select(.comments?) | .comments[] | [.id, .createdAt, .author.id, .author.name, .body ] | @csv' >> $outfile
  done
done
