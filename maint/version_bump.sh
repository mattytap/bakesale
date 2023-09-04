#!/bin/bash

set -e

asker() {
	read -r -p "$1" yn
	case ${yn} in
		[yY]) return 0 ;;
		[nN]) return 1 ;;
		*) asker "$@" ;;
	esac
}

asker "Would you like to proceed? This script will erase all your work. (y/n) " || exit 1
git reset --hard

version=${1:?}
is_latest=${2:-1}
EDITOR=${EDITOR:-nano}

if asker "Would you like to create a new changelog entry? (y/n) "
then
	cur_date=$(date -I)
	sed -e '/Zep7RkGZ52/a\' -e '\n\n\#\# '"${cur_date}"' - Version '"${version}"'\n\n**Release notes here**' -i CHANGELOG.md
fi
${EDITOR} CHANGELOG.md
( git add CHANGELOG.md && git commit -sm "Updated CHANGELOG for ${version}"; ) || true

if sed -E 's/(^autorate_version=\")[^\"]+(\"$)/\1'"${version}"'\2/' -i autorate.sh
then
	echo Cake autorate version updated in autorate.sh
	( git add autorate.sh
	git commit -sm "Updated autorate.sh version to ${version}"; ) || true
fi

if ((is_latest))
then
	if sed -E 's|(<span id=\"version\">)[^\<]+(</span>)|\1'"${version}"'\2|' -i README.md
	then
		echo Latest cake autorate version updated in README.md
	fi
	( git add README.md
	git commit -sm "Updated latest version in README.md to ${version}"; ) || true
fi
