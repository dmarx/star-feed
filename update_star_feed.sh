#!/bin/bash

USERNAME="<Your-GitHub-Username>"
TOKEN="<Your-Personal-Access-Token>"
BUCKET=$1  # Passed from the GitHub Actions workflow

# Function to get the last checked date for a user
get_last_checked_date() {
    local user=$1
    grep "$user" last_checked.txt | cut -d':' -f2 || echo ""
}

# Function to get the starring velocity for a user
get_starring_velocity() {
    local user=$1
    grep "$user" star_velocity.txt | cut -d':' -f2 || echo "0"
}

# Update the last checked date for a user
update_last_checked_date() {
    local user=$1
    local date=$2
    sed -i "/^$user:/d" last_checked.txt
    echo "$user:$date" >> last_checked.txt
}

# Update the starring velocity for a user
update_starring_velocity() {
    local user=$1
    local velocity=$2
    sed -i "/^$user:/d" star_velocity.txt
    echo "$user:$velocity" >> star_velocity.txt
}

# Fetch users you're following
FOLLOWING=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/users/$USERNAME/following" | jq -r '.[].login')

# Filter users based on the provided bucket
if [ "$BUCKET" == "high" ]; then
    # Example: Velocity greater than 10. Adjust accordingly.
    FOLLOWING=$(echo "$FOLLOWING" | while read user; do [ $(get_starring_velocity $user) -gt 10 ] && echo $user; done)
elif [ "$BUCKET" == "medium" ]; then
    # Example: Velocity between 5 and 10.
    FOLLOWING=$(echo "$FOLLOWING" | while read user; do v=$(get_starring_velocity $user); [ $v -le 10 ] && [ $v -gt 5 ] && echo $user; done)
else
    # Example: Velocity 5 or lower.
    FOLLOWING=$(echo "$FOLLOWING" | while read user; do [ $(get_starring_velocity $user) -le 5 ] && echo $user; done)
fi

# Create or clear the output file
echo "Star Feed" > star_feed.txt

# Fetch starred repositories for each user
for user in $FOLLOWING; do
    LAST_CHECKED=$(get_last_checked_date $user)
    if [ -z "$LAST_CHECKED" ]; then
        STARRED_REPOS=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/users/$user/starred" | jq -r '.[].full_name')
    else
        STARRED_REPOS=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/users/$user/starred?since=$LAST_CHECKED" | jq -r '.[].full_name')
    fi

    NEW_REPOS_COUNT=$(echo "$STARRED_REPOS" | wc -l)
    
    # Update the feed only if new repositories were starred
    if [ $NEW_REPOS_COUNT -gt 0 ]; then
        echo "User: $user" >> star_feed.txt
        echo "Starred Repositories:" >> star_feed.txt
        for repo in $STARRED_REPOS; do
            echo "- $repo" >> star_feed.txt
        done
        echo "-------------------" >> star_feed.txt
    fi

    # Update the last checked date and velocity
    CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    update_last_checked_date $user $CURRENT_DATE
    update_starring_velocity $user $NEW_REPOS_COUNT
done
