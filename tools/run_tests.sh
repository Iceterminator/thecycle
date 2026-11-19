#!/usr/bin/env bash
# Lance les tests réseau de tests/ (hôte + client headless) et affiche OK / ÉCHEC par test.
#   bash tools/run_tests.sh                 # tous les tests
#   bash tools/run_tests.sh 03 05           # seulement les tests dont le nom contient 03 ou 05
# Variable GODOT : chemin de l'exécutable (par défaut : celui du CLAUDE.md).
# Journaux : .test_logs/<test>_host.log et _client.log (ignorés par git).

cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
if [ -z "$GODOT" ]; then
	# Le dossier Godot est à côté du dossier « jeux » (3 niveaux au-dessus de la racine du dépôt).
	REPO="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
	REPO="${REPO%/.git}"
	[ -z "$REPO" ] && REPO="$ROOT"
	GODOT="$REPO/../../../Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
fi
if [ ! -f "$GODOT" ]; then
	echo "Godot introuvable : $GODOT (définir GODOT=...)"
	exit 1
fi

TIMEOUT=150   # s, par processus (le test s'arrête seul à 120 s)
LOGS="$ROOT/.test_logs"
mkdir -p "$LOGS"
passed=0
failed=0
failed_names=""

# Arrête un processus lancé en arrière-plan (et le Godot Windows derrière, via taskkill).
stop_process() {
	local pid=$1
	if kill -0 "$pid" 2>/dev/null; then
		local winpid
		winpid=$(cat "/proc/$pid/winpid" 2>/dev/null)
		[ -n "$winpid" ] && taskkill //F //T //PID "$winpid" >/dev/null 2>&1
		kill -9 "$pid" 2>/dev/null
	fi
}

for test in tests/test_*.gd; do
	name=$(basename "$test" .gd)
	if [ $# -gt 0 ]; then
		keep=0
		for filter in "$@"; do
			[[ "$name" == *"$filter"* ]] && keep=1
		done
		[ $keep -eq 0 ] && continue
	fi
	host_log="$LOGS/${name}_host.log"
	client_log="$LOGS/${name}_client.log"
	start=$(date +%s)
	timeout $TIMEOUT "$GODOT" --headless --path . -s tests/runner.gd -- --test="$name" --host --name=ZzTestHote > "$host_log" 2>&1 &
	host_pid=$!
	sleep 3
	timeout $TIMEOUT "$GODOT" --headless --path . -s tests/runner.gd -- --test="$name" --join=127.0.0.1 --name=ZzTestClient > "$client_log" 2>&1
	client_code=$?
	wait $host_pid
	host_code=$?
	stop_process $host_pid
	took=$(( $(date +%s) - start ))
	if [ $host_code -eq 0 ] && [ $client_code -eq 0 ] && grep -q "TEST OK" "$host_log" && grep -q "TEST OK" "$client_log"; then
		echo "OK     $name (${took} s)"
		passed=$((passed + 1))
	else
		echo "ÉCHEC  $name (${took} s, hôte $host_code, client $client_code)"
		grep -h "TEST ECHEC\|SCRIPT ERROR\|Parse Error" "$host_log" "$client_log" | head -5 | sed 's/^/       /'
		failed=$((failed + 1))
		failed_names="$failed_names $name"
	fi
done

echo "Réussis : $passed, échecs : $failed$failed_names"
[ $failed -eq 0 ]
