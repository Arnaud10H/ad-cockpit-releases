#!/bin/sh
# ad-cockpit — installation / remise à niveau en UNE commande, sur n'importe quel poste (Linux, Mac ; Windows : WSL ou le client windows/) :
#   curl -fsSL https://raw.githubusercontent.com/Arnaud10H/ad-cockpit-releases/main/bootstrap.sh | sh
# Options (variables) : AD_HOME (défaut ~/Code/ad-cockpit), AD_UPDATE_CHANNEL (stable|beta), AD_UPDATE_REPO, AD_UPDATE_TOKEN.
# Ce que ça fait : lit le manifeste du canal, télécharge l'archive, vérifie son SHA-256, l'installe (en gardant la config
# de ~/.config/ad-cockpit), puis lance `updater.py postinstall` (dépendances, services, timer de mises à jour).
set -eu
REPO=${AD_UPDATE_REPO:-Arnaud10H/ad-cockpit-releases}
CHANNEL=${AD_UPDATE_CHANNEL:-stable}
DEST=${AD_HOME:-$HOME/Code/ad-cockpit}
BASES="${AD_UPDATE_URL:-} https://raw.githubusercontent.com/$REPO/main https://artisan-digital.eu/cockpit/channel"
AUTH=""; [ -n "${AD_UPDATE_TOKEN:-}" ] && AUTH="Authorization: Bearer $AD_UPDATE_TOKEN"

command -v python3 >/dev/null || { echo "python3 requis (Mac : xcode-select --install ; Linux : paquet python)"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
M=""
for b in $BASES; do
  if curl -fsSL ${AUTH:+-H "$AUTH"} "$b/$CHANNEL.json" -o "$TMP/m.json" 2>/dev/null; then M="$TMP/m.json"; break; fi
done
[ -n "$M" ] || { echo "canal $CHANNEL introuvable ($BASES)"; exit 1; }
eval "$(python3 -c 'import json,sys,shlex; m=json.load(open(sys.argv[1])); print("VER=%s URL=%s SHA=%s" % tuple(shlex.quote(m.get(k,"")) for k in ("version","url","sha256")))' "$M")"
echo "→ ad-cockpit v$VER ($CHANNEL)"
curl -fSL ${AUTH:+-H "$AUTH"} "$URL" -o "$TMP/a.tgz"
GOT=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$TMP/a.tgz")
[ -z "$SHA" ] || [ "$GOT" = "$SHA" ] || { echo "SHA-256 invalide — archive refusée"; exit 1; }
mkdir -p "$DEST"
if [ -f "$DEST/VERSION" ]; then
  mkdir -p "$HOME/.local/state/ad-cockpit"
  tar czf "$HOME/.local/state/ad-cockpit/backup-v$(cat "$DEST/VERSION")-bootstrap-$(date +%Y%m%d-%H%M%S).tgz" -C "$(dirname "$DEST")" --exclude node_modules --exclude .git --exclude @girs "$(basename "$DEST")" || true
fi
tar xzf "$TMP/a.tgz" -C "$DEST" --strip-components=1
echo "→ installé dans $DEST"
python3 "$DEST/scripts/updater.py" postinstall
echo "✓ ad-cockpit v$VER prêt. Mises à jour suivantes : ⚙ Mises à jour (ou automatiques selon AUTO_UPDATE)."
