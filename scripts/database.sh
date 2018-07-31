import_database() {
	if grep -q $1 backups/.ignore; then
		h2 "Ignoring file because it is listed in backups/.ignore"
	else
		while ! pg_isready -h $DB_SERVER; do
			h2 "Waiting for PostreSQL server"
			sleep 1
		done

		cat "$1" | psql -h $DB_SERVER -U $DB_USER && echo "$1" >>backups/.ignore
	fi
}

check_database() {
	declare zip_file
	declare sql_file

	# Save DB credentials
	echo $DB_SERVER:$DB_PORT:$DB_DATABASE:$DB_USER:$DB_PASSWORD >~/.pgpass
	chmod 600 ~/.pgpass

	cd /var/www/html/storage

	# Find most recent zip file (mtime)
	zip_file=$(find backups -name "*.zip" -printf "%t %p\n" | sort -n | rev | cut -d' ' -f 1 | rev | tail -n1)

	if [[ "$zip_file" ]]; then
		h2 "Decompressing zip file: ${zip_file}"

		# Unzip file and force overwrite
		unzip -o $zip_file -d backups
	fi

	# Find most recent sql file (mtime)
	sql_file=$(find backups -name "*.sql" -printf "%t %p\n" | sort -n | rev | cut -d' ' -f 1 | rev | tail -n1)

	if [[ "$sql_file" ]]; then
		h2 "Database dump found: ${sql_file}"

		import_database $sql_file
	else
		h2 "Setup Craft CMS"

		while ! pg_isready -h $DB_SERVER; do
			h2 "Waiting for PostreSQL server"
			sleep 1
		done

		cd /var/www/html &&
			./craft setup/security-key &&
			./craft install --interactive=0 --email="${CRAFTCMS_EMAIL}" --username="${CRAFTCMS_USERNAME:-admin}" --password="${CRAFTCMS_PASSWORD}" --siteName="${CRAFTCMS_SITENAME}" --siteUrl="${CRAFTCMS_SITEURL:-@web}"
	fi
}
