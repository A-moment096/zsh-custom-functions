lh() {
  eza -d $(eza -A | rg '^\.') --icons=auto
}

llh() {
  eza -ldh $(eza -A | rg '^\.') --icons=auto
}
