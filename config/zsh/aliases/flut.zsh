#!/bin/zsh

# Move into the nearest Flutter project (a directory holding pubspec.yaml).
#
# `flutter build` fails outside a project, and the old menu swallowed that: the
# split-APK step would fail, `build_release` would return before the bundle, and
# the menu closed with no bundle and no obvious reason. This makes the failure a
# sentence instead.
_flut_enter_project() {
  local dir="$PWD"
  while [[ "$dir" != "/" && ! -f "$dir/pubspec.yaml" ]]; do
    dir="${dir:h}"
  done

  if [[ ! -f "$dir/pubspec.yaml" ]]; then
    print -u2 "flut: no pubspec.yaml in $PWD or any parent - run this from a Flutter project."
    return 1
  fi

  cd "$dir" || return 1
}

flut() {
  # Anything after `flut` goes straight through, so a one-off build does not mean
  # leaving the menu behind. Bare `flut` still opens it.
  if (( $# > 0 )); then
    flutter "$@"
    return
  fi

  local reset=$'\033[0m'
  local blue=$'\033[38;5;75m'
  local cyan=$'\033[38;5;80m'
  local green=$'\033[38;5;114m'
  local yellow=$'\033[38;5;221m'
  local purple=$'\033[38;5;141m'
  local red=$'\033[38;5;203m'
  local orange=$'\033[38;5;208m'

  typeset -A commands=(
    ["󰄬 Doctor"]="flutter doctor"
    ["󰚰 Upgrade Project"]="flutter upgrade"
    ["󰚰 Update SDK (git pull)"]="update_sdk"
    ["󰇚 Get Packages"]="flutter pub get"
    ["󰆴 Clean"]="flutter clean"
    ["󰐕 Build APK"]="flutter build apk --release"
    ["󰐕 Build APK (split per ABI)"]="flutter build apk --release --split-per-abi"
    ["󰐕 Build Release (split APKs + App Bundle)"]="build_release"
    ["󰐕 Build App Bundle"]="flutter build appbundle --release"
    ["󰖟 Build Web (auto renderer)"]="flutter build web --release"
    ["󰖟 Build Web (html)"]="flutter build web --release --web-renderer html"
    ["󰖟 Build Web (canvaskit)"]="flutter build web --release --web-renderer canvaskit"
    ["󰐊 Run on Device"]="flutter run"
    ["󰐊 Run Web"]="flutter run -d chrome"
    ["󰐊 OddsVault Web"]="oddsvault web"
    ["󰒓 Devices"]="flutter devices"
    ["󰄬 Analyze"]="flutter analyze"
    ["󰄬 Test"]="flutter test"
    ["󰐕 Create Project"]="create_project"
    ["󰅙 Quit"]="return"
  )

  local -a menu=(
    "${cyan}󰄬${reset} ${purple}Doctor${reset}"
    "${yellow}󰚰${reset} ${purple}Upgrade Project${reset}"
    "${yellow}󰚰${reset} ${purple}Update SDK (git pull)${reset}"
    "${green}󰇚${reset} ${purple}Get Packages${reset}"
    "${red}󰆴${reset} ${purple}Clean${reset}"
    "${green}󰐕${reset} ${purple}Build APK${reset}"
    "${green}󰐕${reset} ${purple}Build APK (split per ABI)${reset}"
    "${green}󰐕${reset} ${purple}Build Release (split APKs + App Bundle)${reset}"
    "${green}󰐕${reset} ${purple}Build App Bundle${reset}"
    "${green}󰖟${reset} ${purple}Build Web (auto renderer)${reset}"
    "${green}󰖟${reset} ${purple}Build Web (html)${reset}"
    "${green}󰖟${reset} ${purple}Build Web (canvaskit)${reset}"
    "${green}󰐊${reset} ${purple}Run on Device${reset}"
    "${green}󰐊${reset} ${purple}Run Web${reset}"
    "${green}󰐊${reset} ${purple}OddsVault Web${reset}"
    "${cyan}󰒓${reset} ${purple}Devices${reset}"
    "${cyan}󰄬${reset} ${purple}Analyze${reset}"
    "${cyan}󰄬${reset} ${purple}Test${reset}"
    "${green}󰐕${reset} ${purple}Create Project${reset}"
    "${orange}󰅙${reset} ${purple}Quit${reset}"
  )

  local choice plain_choice
  choice=$(printf "%s\n" "${menu[@]}" | fzf --no-preview --ansi --height=20 --border --prompt "Flutter › ")
  plain_choice=$(print -r -- "$choice" | sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g')

  [[ -n $plain_choice ]] || return 0

  local cmd="${commands[$plain_choice]}"

  if [[ -z $cmd ]]; then
    print -u2 "flut: no command is mapped to '$plain_choice'"
    return 1
  fi

  # Builds and runs have to start at the project root, or `flutter` cannot find
  # pubspec.yaml and the step fails before doing anything.
  case "$cmd" in
    build_release|'flutter build'*|'flutter pub get'|'flutter clean'|'flutter run'*)
      _flut_enter_project || return 1
      ;;
  esac

  eval "$cmd"
  local status=$?

  if (( status != 0 )); then
    print -u2 "flut: command exited with status $status"
  fi

  return $status
}

update_sdk() {
  (cd ~/flutter && git pull && flutter upgrade)
}

# Both release artifacts in one pass: the per-ABI APKs for sideloading onto a phone,
# and the App Bundle the Play Console takes. The bundle only runs if the APKs built,
# so a failure reports itself instead of being buried under a second build.
build_release() {
  _flut_enter_project || return 1

  echo "▶ Building split APKs (release)..."
  if ! flutter build apk --release --split-per-abi; then
    echo "❌ Split APK build failed - skipping the App Bundle." >&2
    return 1
  fi

  echo "▶ Building App Bundle (release)..."
  if ! flutter build appbundle --release; then
    echo "❌ App Bundle build failed." >&2
    return 1
  fi

  echo "✅ Release artifacts:"
  ls -1 build/app/outputs/flutter-apk/app-*-release.apk 2>/dev/null
  ls -1 build/app/outputs/bundle/release/*.aab 2>/dev/null
}

create_project() {
  echo -n "Enter project name: "
  read pname
  if [[ -n "$pname" ]]; then
    flutter create "$pname" && echo "✅ Project created: $pname"
  else
    echo "❌ No name entered."
  fi
}

# ------------------------------------------------------- #
# OddsVault — start the app by name.
#   oddsvault web             # Flutter web on 127.0.0.1:5173 against the local API
#   oddsvault web --profile   # anything after `web` is passed to `flutter run`
#   oddsvault web --free      # reclaim the port from a leftover server, then run
#   oddsvault stop            # stop whatever is listening on the port
# Overridable: ODDSVAULT_REPO, ODDSVAULT_API_BASE, ODDSVAULT_WEB_PORT.
# ------------------------------------------------------- #

# The listener holding <port>, or nothing. Only the IPv4 side counts: [::1]:<port>
# on this machine belongs to an unrelated Vite app and cannot collide with a
# 127.0.0.1 bind, while [::] is a dual-stack wildcard that can.
_oddsvault_port_holder() {
  ss -ltnp 2>/dev/null | awk -v p=":$1" \
    '$4 ~ p"$" && ($4 !~ /^\[/ || $4 == "[::]" p)'
}

# The pid of that listener, so it can be stopped without a second lookup.
_oddsvault_port_pid() {
  _oddsvault_port_holder "$1" | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2
}

# Stop the process holding <port>. Deliberately narrow: it kills the one pid the
# kernel reports for that socket, never anything matched by name.
_oddsvault_free_port() {
  local pid
  pid=$(_oddsvault_port_pid "$1")
  if [[ -z $pid ]]; then
    print "oddsvault: nothing is listening on $1"
    return 0
  fi
  print "oddsvault: stopping pid $pid on port $1"
  kill "$pid" 2>/dev/null
  local waited=0
  while (( waited < 20 )) && [[ -n $(_oddsvault_port_pid "$1") ]]; do
    sleep 0.25
    (( waited++ ))
  done
  if [[ -n $(_oddsvault_port_pid "$1") ]]; then
    print -u2 "oddsvault: pid $pid did not stop in time - finish it with: kill -9 $pid"
    return 1
  fi
  return 0
}

# A loopback address that is free on <port>, so the app can still be served when
# 127.0.0.1 is taken by something that must not be killed.
_oddsvault_free_host() {
  local candidate
  for candidate in 127.0.0.1 127.0.0.2 127.0.0.3; do
    if ! ss -ltn 2>/dev/null | awk -v a="${candidate}:$1" '$4 == a' | grep -q .; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}

oddsvault() {
  local subcommand="$1"
  [[ $# -gt 0 ]] && shift

  local repo="${ODDSVAULT_REPO:-$HOME/Apex/oddsVault}"
  local app_dir="$repo/apps/flutter_app"
  local api_base="${ODDSVAULT_API_BASE:-http://127.0.0.1:8010}"
  local port="${ODDSVAULT_WEB_PORT:-5173}"
  local reclaim=0

  # `--free` may arrive before or after the subcommand; pull it out so it is never
  # handed to `flutter run`.
  local -a extra=()
  local arg
  for arg in "$@"; do
    case "$arg" in
      --free | -f) reclaim=1 ;;
      *) extra+=("$arg") ;;
    esac
  done

  case "$subcommand" in
    web)
      if [[ ! -d "$app_dir" ]]; then
        print -u2 "oddsvault: no Flutter app at $app_dir (override with ODDSVAULT_REPO)"
        return 1
      fi

      # A left-over server on the port is the common case, so say who holds it and
      # how to deal with it rather than refusing with no way forward.
      local holder
      holder=$(_oddsvault_port_holder "$port")
      if [[ -n $holder ]]; then
        if (( reclaim )); then
          _oddsvault_free_port "$port" || return 1
        else
          print -u2 "oddsvault: port $port is already taken - stop that process first:"
          print -u2 -- "$holder"
          print -u2 "oddsvault: or run 'oddsvault web --free' to stop it and continue"
          return 1
        fi
      fi

      # Still held after that (a dual-stack listener we must not kill): move to
      # another loopback address on the same port rather than silently serving the
      # app somewhere nothing is looking for it.
      local host=127.0.0.1
      if [[ -n $(_oddsvault_port_holder "$port") ]]; then
        if ! host=$(_oddsvault_free_host "$port"); then
          print -u2 "oddsvault: port $port is taken on every loopback address; try ODDSVAULT_WEB_PORT=$(( port + 1 ))"
          return 1
        fi
        print -u2 "oddsvault: 127.0.0.1:$port is unavailable - serving on ${host}:${port} instead"
      fi

      # A previous run leaves its own served output behind, and that stale bundle is
      # what the browser then loads. Clearing it means the first load is the code as
      # it is now.
      if [[ -d "$app_dir/build/web" ]]; then
        print "oddsvault: clearing $app_dir/build/web (stale served output)"
        rm -rf "$app_dir/build/web"
      fi

      print "oddsvault: Flutter web -> http://${host}:${port}/   (API ${api_base})"
      ( cd "$app_dir" && flutter run -d web-server --web-port="$port" \
          --web-hostname="$host" --dart-define=API_BASE_URL="$api_base" "${extra[@]}" )
      ;;
    stop)
      _oddsvault_free_port "$port"
      ;;
    "")
      print "usage: oddsvault web [--free] [extra flutter run args]"
      print "       Flutter web on 127.0.0.1:${port}, API ${api_base}"
      print "       oddsvault stop    free port ${port} from a leftover server"
      ;;
    *)
      print -u2 "oddsvault: unknown subcommand '$subcommand' (try: oddsvault web)"
      return 1
      ;;
  esac
}
