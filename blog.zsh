function blog() {
    # Set your paths here
    local -r BLOG_DIR="$HOME/develop/blog"
    local -r EDITOR="nvim"
    local -r POSTS_DIR="$BLOG_DIR/content/posts"

    # Check if we're in the blog directory already
    if [[ "$PWD" != "$BLOG_DIR"* ]]; then
        cd "$BLOG_DIR" || { echo "Error: Could not cd to $BLOG_DIR"; return 1 }
    fi

    local -r fd_result=$(
      fd --type f --color=never 'index.md' $POSTS_DIR
      )

    # Parse command line arguments
    case "$1" in
        pull)
            git pull origin
            ;;
        new)
            hugo new "content/posts/$2/index.md"
            ;;
        edit)
            local fzf_command="fzf \
                  --height 40%\
                  --reverse\
                  --prompt='Posts> '\
                  --preview \
                  'bat --color=always --style=numbers {} 2>/dev/null' \
                  --with-nth=8.. \
                  --delimiter='/' \
            "
            [[ -n $2 ]] && fzf_command+=" --query $2"
            
            local -r fzf_result=$(echo $fd_result | eval $fzf_command)
            [[ -n $fzf_result ]] && $EDITOR "$fzf_result"
            ;;
        write)
            hugo new "content/posts/$2/index.md"
            $EDITOR "$fzf_result"
            ;;
        server)
            hugo server -D &  # Run in background with draft posts
            sleep 2  # Wait for server to start
            xdg-open "http://localhost:1313"  # Open in default browser (Mac)
            # For Linux, you might use: xdg-open "http://localhost:1313"
            ;;
        deploy)
            if [[ -z "$2" ]]; then
                echo "Usage: blog deploy <commit string>"
                return 1
            fi
            git add . && git commit -m "$2" && git push origin
            ;;
        *)
            echo "Blog management helper"
            echo ""
            echo "Usage: blog [command]"
            echo ""
            echo "Commands:"
            echo "  new <title>              Create a new post with the given title"
            echo "  edit <file>              Open an existing post for editing"
            echo "  write <file>             Create and edit the post with title"
            echo "  deploy <commit string>   Build and deploy to github"
            echo "  pull                     Pull from github"
            echo "  server                   Start local dev server and open browser"
            echo ""
            echo "Current blog directory: $BLOG_DIR"
            ;;
    esac
}

_blog() {
  local -a commands
  commands=(
    'new:Create a new post'
    'edit:Edit an existing post'
    'write:Create and edit a post'
    'deploy:Commit and push changes'
    'pull:Pull from GitHub'
    'server:Start local Hugo server'
  )

  local curcontext="$curcontext" state line
  _arguments -C \
    '1:command:->cmds' \
    '2:argument:->args' \
    '*:: :->rest'

  case $state in
    cmds)
      _describe 'command' commands
      ;;
    args)
      case $words[2] in
        edit|write)
          _message 'search for blog name'
          ;;
        deploy)
          _message 'commit message'
          ;;
        new)
          _message 'post title'
          ;;
      esac
      ;;
  esac
}
compdef _blog blog
