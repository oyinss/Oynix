#!/bin/zsh

exp.() {
  typeset -A commands=(
    ["📶 Check text_expander Status"]="systemctl status text_expander --no-pager"
    ["🚀 Start text_expander"]="sudo systemctl start text_expander"
    ["🛑 Stop text_expander"]="sudo systemctl stop text_expander"
    ["🔄 Restart text_expander"]="sudo systemctl restart text_expander"
    ["📜 View Logs"]="journalctl -u text_expander --no-pager -n 100"
    ["🧩 List Triggers"]="/usr/local/bin/text_expander --list-triggers"
    ["⚙️ Edit Base Config (nvim)"]="nvim ~/.config/text_expander/base.yml"
    ["📝 Edit Matches"]="edit_match"
    ["➕ Add New Trigger"]="add_trigger"
    ["🚪 Quit"]="return"
  )

  local choice=$(printf "%s\n" "${(@k)commands}" | fzf --height=12 --prompt="🧠  text_expander Menu: " --border)

  if [[ -n $choice ]]; then
    eval "${commands[$choice]}"
  else
    echo "❌ No option selected."
  fi
}

add_trigger() {
  local match_dir="$HOME/.config/text_expander"
  local target=$(find "$match_dir" -maxdepth 1 -type f -name '*.yml' | fzf --prompt="📄 Select target YAML: " --height=10)
  local tmpfile=$(mktemp)

  if [[ -z "$target" ]]; then
    echo "❌ No file selected."
    return 1
  fi

  echo "📄 Selected file: $target"
  echo "🧠 You can add multiple triggers. Press ENTER on an empty trigger to finish."
  echo

  while true; do
    echo -n "🧵 Enter Trigger (e.g ;sea) or ENTER to Exit: "
    read trigger
    [[ -z "$trigger" ]] && break

    echo -n "💬 Enter Replacement: "
    read replace

    if [[ -z "$replace" ]]; then
      echo "❌ Replace text cannot be empty."
      continue
    fi

    echo "  - trigger: \"$trigger\"" >> "$tmpfile"
    echo "    replace: \"$replace\"" >> "$tmpfile"
    echo "✅ Buffered trigger \"$trigger\""
  done

  if [[ -s "$tmpfile" ]]; then
    echo >> "$target"
    cat "$tmpfile" >> "$target"
    echo "📦 All triggers appended to $target"
    echo "🔁 Run 'sudo systemctl restart text_expander' when ready."
  else
    echo "⚠️ No triggers were added."
  fi

  rm -f "$tmpfile"
}

edit_match() {
  local match_dir="$HOME/.config/text_expander"
  local target=$(find "$match_dir" -maxdepth 1 -type f -name '*.yml' | fzf --prompt="📝 Select YAML to edit: " --height=10)

  if [[ -z "$target" ]]; then
    echo "❌ No file selected."
    return 1
  fi

  nvim "$target"
}
