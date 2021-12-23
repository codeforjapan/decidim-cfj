#!/bin/bash
function print_orgs() {
  export PGPASSWORD=$RDS_PASSWORD; psql -h $RDS_HOSTNAME -U $RDS_USERNAME -c "SELECT id, name FROM decidim_organizations" $RDS_DB_NAME
}

if [ "$1" = "" ]; then
  print_orgs
  echo "-------------------"
  echo "please specify ORG_ID ;  get_user_data.sh ORG_ID"
  exit 1
fi

echo ORG_ID is $1
ORG_ID=$1

out_file=$(mktemp)
json_file=$(mktemp)


echo "[" > ${json_file}
export PGPASSWORD=$RDS_PASSWORD; psql -h $RDS_HOSTNAME -U $RDS_USERNAME -c "SELECT json_build_object('id', B.id, 'nickname',nickname,'email', email, 'created_at', to_char(B.created_at, 'YYYY/MM/DD'),'sign_in_count', sign_in_count, 'last_sign_in_at', to_char(last_sign_in_at, 'YYYY/MM/DD'), 'data',  metadata) FROM public.decidim_authorizations as A RIGHT OUTER JOIN decidim_users as B on A.decidim_user_id = B.id where decidim_organization_id = ${ORG_ID} and B.deleted_at is null;" -A -t  $RDS_DB_NAME > ${out_file}

awk -v eof=`wc -l ${out_file} | awk '{print $1}'` 'BEGIN{ORS = ",\n"}{if (NR==eof) ORS=""; print $0}' ${out_file} >> ${json_file}
echo "]" >> ${json_file}


echo "id, created_at, sign_in_count, last_sign_in, nickname, real_name, email, gender, address, birth_year, occupation" > /tmp/metadata.csv

cat ${json_file} | jq -r '.[] | [.id,.created_at, .sign_in_count,.last_sign_in_at,.nickname,.data.real_name, .email, .data.gender, .data.address, .data.birth_year, .data.occupation] | @csv' >> /tmp/metadata.csv

echo "/tmp/metadata.csv is created"
