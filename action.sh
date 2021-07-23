trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   
    printf '%s' "$var"
}

main(){
	set -euo pipefail

	if [ -z "$EXCLUDES" ]; then
		echo "Exclude nothing."
	else
		SAVEIFS=$IFS   # Save current IFS
		IFS=$'\n'      # Change IFS to new line
		excludeArray=($EXCLUDES) # split to array $EXCLUDES
		IFS=$SAVEIFS   # Restore IFS

		# get length of the array
		excludeLength=${#excludeArray[@]}
		echo "Number of excludes is ${excludeLength}"
		# use for loop to read all values and indexes
		for (( i=0; i<${arraylength}; i++ ));
		do
			echo "$i, value: >${excludeArray[$i]}<"
			excludeArray[$i]=trim excludeArray[$i]
			echo "$i, value: >${excludeArray[$i]}<"
		done

		declare -a EXCLUDES=("--exclude" "${excludeArray[@]}") # Add git command
	fi

	# Create Temporary Directory
	TEMP=$(mktemp -d)

	# Set up git
	git config --global user.email "$GIT_EMAIL"
	git config --global user.name "$GIT_USER"
	git clone "$REPO" "$TEMP"
	cd "$TEMP"

	# Check if branch exists
	LS_REMOTE="$(git ls-remote --heads origin refs/heads/"$BRANCH")"
	if [[ -n "$LS_REMOTE" ]]; then
		echo "Checking out $BRANCH from origin."
		git checkout "$BRANCH"
	else
		echo "$BRANCH does not exist on origin, creating new branch."
		git checkout -b "$BRANCH"
	fi

	# Sync $TARGET folder to $REPO state repository with excludes
	f="/"
	if [[ -f "${GITHUB_WORKSPACE}/${SOURCE}" ]]; then
		f=""
	fi
	echo "running 'rsync -avh --delete ${EXCLUDES[*]} $GITHUB_WORKSPACE/${SOURCE}${f} $TEMP/$TARGET'"
	rsync -avh --delete "${EXCLUDES[@]}" "$GITHUB_WORKSPACE/${SOURCE}${f}" "$TEMP/$TARGET"

	# Add changes
	git add .

	# Successfully finish early if there is nothing to commit
	if [ -z "$(git diff-index --quiet HEAD)" ]; then
		echo "nothing to commit"
		exit 0
	fi

	commit_signoff=""
	if [ "${GIT_COMMIT_SIGN_OFF}" = "true" ]; then
		commit_signoff="-s"
	fi

	if [[ -n "$GIT_COMMIT_MSG" ]]; then
		git commit ${commit_signoff} -m "$GIT_COMMIT_MSG"
	else
		SHORT_SHA=$(echo "$GITHUB_SHA" | head -c 6)
		MSGHEAD="Automatic CI SYNC Commit ${SHORT_SHA}"
		MSGDETAIL="Syncing with ${GITHUB_REPOSITORY} commit ${GITHUB_SHA}"
		git commit ${commit_signoff} -m "${MSGHEAD}" -m "${MSGDETAIL}"
	fi

	if [[ -n "$LS_REMOTE" ]]; then
		git push
	else
		git push origin "$BRANCH"
	fi
}

main
