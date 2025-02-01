find $SOURCES -type d -name ".git" -execdir bash -c '
  repo_dir=$(dirname "{}")
  cd "$repo_dir" || exit
  REMOTE_URL=$(git remote get-url origin)
  case "$REMOTE_URL" in
    http*)
      NEW_URL=$(echo "$REMOTE_URL" | sed -E "s#https?://([^@]+@)?([^/]+)/([^/]+)/([^/]+)(\.git)?#git@\\2:\\3/\\4#")
      git remote set-url origin "$NEW_URL"
      ;;
    *)
      ;;
  esac
' \;