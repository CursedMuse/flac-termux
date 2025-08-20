# …change: readonly VERSION="12.3-termux" → readonly 
# VERSION="12.3-termux"#!/data/data/com.termux/files/usr/bin/zsh

# Termux FLAC Converter Pro v12.2 — (Optimized specifically for Samsung Galaxy A14 5G — Android 
# 15) sanity check ----- Shell & env 
# -------------------------------------------------------------
zsh -n Flac.zsh || { echo "Syntax error"; exit 1; }setopt ERR_EXIT NO_UNSET PIPE_FAIL 2>/dev/null 
|| true setopt EXTENDED_GLOB NULL_GLOB RC_EXPAND_PARAM zmodload -F zsh/zutil b:zparseopts 
2>/dev/null || true

typeset -A C C[RESET]=$'\033[0m'; C[RED]=$'\033[0;31m'; C[GREEN]=$'\033[0;32m' 
C[YELLOW]=$'\033[1;33m'; C[CYAN]=$'\033[0;36m'; C[BOLD]=$'\033[1m' C[BLUE]=$'\033[0;34m'; 
C[MAG]=$'\033[0;35m' git add Flac.zsh export TMPDIR="/data/data/com.termux/files/usr/tmp" export 
PATH="/data/data/com.termux/files/usr/bin:$PATH" export LC_ALL=C git commit -m "v12.3: tune 
thresholds & guards" readonly VERSION="12.2-termux" readonly START_PWD="${PWD}" readonly 
LOG_DIR="${HOME}/.flac_converter_logs" readonly DATE_STAMP=$(date +%Y%m%d_%H%M%S) readonly 
LOG_FILE="${LOG_DIR}/flac_conversion_${DATE_STAMP}.log" mkdir -p "$LOG_DIR" git push -u origin 
fast-streak-tuning log(){ local L=$1; shift
  case $L in ERROR) print -r -- "${C[RED]}[ERROR]${C[RESET]} $*";; WARN) print -r -- 
    "${C[YELLOW]}[WARN] ${C[RESET]} $*";; INFO) print -r -- "${C[GREEN]}[INFO] ${C[RESET]} $*";; 
    STEP) print -r -- "${C[BLUE]}[STEP] ${C[RESET]} $*";; OK) print -r -- "${C[GREEN]}[OK] 
    ${C[RESET]} $*";; DEBUG) [[ ${VERBOSE:-0} -eq 1 ]] && print -r -- 
    "${C[CYAN]}[DEBUG]${C[RESET]} $*";; *) print -r -- "$L $*";;
# now open the PR esac
gh pr create -B main -H fast-streak-tuning \} _logfile(){ local ts=$(date '+%Y-%m-%d %H:%M:%S'); 
echo "[$ts] [$1] $2" >> "$LOG_FILE"; }
  --title "Tune streak thresholds & guards" \ SP_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' spinner_run(){ emulate -L 
zsh; local label="$1"; shift
  --body "Adjust short/long streak to 10/10, strict prompts, guards for arrays."  print -n -- "${C[BLUE]}[WORK]${C[RESET]} $label "
  "$@" & local pid=$!
  local i=1 n=${#SP_CHARS}
  while kill -0 $pid 2>/dev/null; do
    local ch=${SP_CHARS[$i,$i]}
    print -n -- " $ch\r${C[BLUE]}[WORK]${C[RESET]} $label "
    (( i = (i % n) + 1 ))
    sleep 0.12
    [[ $PANIC -eq 1 ]] && { kill $pid 2>/dev/null; wait $pid 2>/dev/null; break; }
  done
  wait $pid; local rc=$?
  print -r -- " $([[ $rc -eq 0 ]] && echo ${C[GREEN]}✓${C[RESET]} || echo ${C[RED]}✗${C[RESET]})"
  return $rc
}
draw_bar(){ emulate -L zsh
  local cur=$1 total=$2 width=$3 label="$4"
  (( total<1 ))&&total=1; (( cur>total ))&&cur=$total
  local pct=$(( cur*100/total ))
  local fill=$(( pct*width/100 )); (( fill<0 ))&&fill=0; (( fill>width ))&&fill=$width
  local empty=$(( width-fill ))
  local bar_fill=$(printf "%*s" "$fill" ""|tr ' ' '=')
  local bar_empty=$(printf "%*s" "$empty" "")
  printf "\r${C[MAG]}[PROG]${C[RESET]} %-25s |%s%s| %3d%% (%d/%d)" "$label" "$bar_fill" "$bar_empty" "$pct" "$cur" "$total"
}
newline(){ print ""; }
flash_banner(){ local msg="$1"; print -r -- "\n${C[BOLD]}==================== ${msg} ====================${C[RESET]}"; print -n $'\a'; }

: ${FLAC_COMPRESSION:=8}; : ${NICE_LEVEL:=12}; : ${MAX_PARALLEL_JOBS:=2}; : ${VERBOSE:=0}
: ${ASSUME_YES:=false}; : ${DRY_RUN:=false}; : ${SKIP_MAINT:=false}
IN_PLACE_MODE=false; PRESERVE_ORIGINALS=false; VERIFY_MODE=true
INPUT_DIR="${START_PWD}"; OUTPUT_FOLDER_NAME="flac_output"; OUTPUT_DIR=""
CSV_FILE=""; PRINT_STATS=false; PRINT_STATS_DETAIL=false
CLI_JOBS_SET=0; CLI_COMP_SET=0

TOTAL_FILES=0 CONVERTED_FILES=0 COPIED_FILES=0 SKIPPED_FILES=0 ERROR_FILES=0
typeset -a WORKER_PIDS=()
START_EPOCH=$(date +%s); PEAK_TEMP_C=-999; TOTAL_INPUT_AUDIO_SEC=0; PRESET_USED=""

ask_yes_no(){
  local prompt="$1"; local default="$2"
  if [[ "$ASSUME_YES" == "true" ]]; then
    REPLY_YN="Y"; print -r -- "$prompt ${C[BOLD]}$default${C[RESET]} (auto)"; return 0
  fi
  local ans
  while true; do
    if [[ "$default" == "Y" ]]; then
      read -k1 ans "?${prompt} [Y/n]: "; echo; [[ -z "$ans" ]] && ans="y"
    else
      read -k1 ans "?${prompt} [y/N]: "; echo; [[ -z "$ans" ]] && ans="n"
    fi
    case "${ans:l}" in
      y) REPLY_YN="Y"; return 0;;
      n) REPLY_YN="N"; return 1;;
      *) print -r -- "${C[YELLOW]}Please type y or n${C[RESET]}";;
    esac
  done
}

lower_ext(){ echo "${1##*.}"|tr '[:upper:]' '[:lower:]'; }
now_ms(){ if date +%s%3N >/dev/null 2>&1; then date +%s%3N; else echo $(( $(date +%s)*1000 )); fi }
check_charging(){ if command -v termux-battery-status &>/dev/null; then local bs; bs=$(termux-battery-status|grep '"status"'|cut -d'"' -f4); [[ "$bs" == "CHARGING" || "$bs" == "FULL" ]] && return 0; fi
  if [[ -r /sys/class/power_supply/battery/status ]]; then local s2=$(cat /sys/class/power_supply/battery/status 2>/dev/null); [[ "$s2" == "Charging" || "$s2" == "Full" ]] && return 0; fi; return 1; }
check_temp_c(){ local tfile t; for tfile in /sys/class/thermal/thermal_zone*/temp; do [[ -r "$tfile" ]]||continue; t=$(cat "$tfile" 2>/dev/null); (( t>0 ))||continue; (( t>1000 ))&&{ echo $((t/1000)); return; }; echo $t; return; done; echo 40; }
decide_preset(){ local charging="false" tempC=$(check_temp_c); check_charging && charging="true"
  if [[ "$charging" == "false" ]]; then (( tempC>45 ))&&{ echo ECO; return; }; echo BALANCED
  else (( tempC<42 ))&&{ echo PERFORMANCE; return; }; echo BALANCED; fi }
apply_preset(){ local p="$1"; PRESET_USED="$p"
  case "$p" in
    ECO)          (( ! CLI_JOBS_SET ))&&MAX_PARALLEL_JOBS=1; (( ! CLI_COMP_SET ))&&FLAC_COMPRESSION=6;  NICE_LEVEL=12;;
    BALANCED)     (( ! CLI_JOBS_SET ))&&MAX_PARALLEL_JOBS=2; (( ! CLI_COMP_SET ))&&FLAC_COMPRESSION=8;  NICE_LEVEL=12;;
    PERFORMANCE)  (( ! CLI_JOBS_SET ))&&MAX_PARALLEL_JOBS=3; (( ! CLI_COMP_SET ))&&FLAC_COMPRESSION=8;  NICE_LEVEL=10;;
    *)            (( ! CLI_JOBS_SET ))&&MAX_PARALLEL_JOBS=2; (( ! CLI_COMP_SET ))&&FLAC_COMPRESSION=8;  NICE_LEVEL=12;;
  esac
  (( MAX_PARALLEL_JOBS<1 ))&&MAX_PARALLEL_JOBS=1; (( MAX_PARALLEL_JOBS>3 ))&&MAX_PARALLEL_JOBS=3
  log STEP "Preset: $PRESET_USED (jobs=$MAX_PARALLEL_JOBS comp=$FLAC_COMPRESSION nice=$NICE_LEVEL)"
}

REQUIRED_CMDS=(ffmpeg ffprobe flac metaflac sox jq)
REQUIRED_PKGS=(ffmpeg flac sox jq coreutils zsh util-linux libsndfile)
missing_list(){ local miss=() c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || miss+=("$c"); done; echo "${(j: :)miss}"; }
pkg_maintenance(){ spinner_run "pkg update -y" pkg update -y || return 1
                   spinner_run "pkg upgrade -y" pkg upgrade -y || return 1
                   spinner_run "Installing packages" pkg install -y "${REQUIRED_PKGS[@]}" || return 1; }
check_or_install_deps(){
  local miss=$(missing_list "${REQUIRED_CMDS[@]}")
  if [[ -z "$miss" ]]; then log OK "All tools present."; return 0; fi
  log WARN "Missing: ${C[BOLD]}$miss${C[RESET]}"
  [[ "$SKIP_MAINT" == "true" ]] && { log ERROR "Maintenance skipped; tools missing."; return 1; }
  ask_yes_no "Run package maintenance (update/upgrade/install) now?" "Y" || return 1
  if pkg_maintenance; then
    miss=$(missing_list "${REQUIRED_CMDS[@]}"); [[ -n "$miss" ]] && { log ERROR "Still missing: $miss"; return 1; }
    log OK "Dependencies ready."
  else
    ask_yes_no "Maintenance failed. Continue anyway?" "N" || return 1
  fi
}

csv_escape(){ local s="$1"; s="${s//\"/\"\"}"; echo "\"$s\""; }
csv_init(){ print -r -- 'relative_path,input_sr,channels,input_bits,flac_bits,compression,encode_secs,input_secs,speed_x,verified,preset' > "$CSV_FILE"; }
csv_append(){ print -r -- "$1" >> "$CSV_FILE"; }
print_stats_table(){
  [[ ! -s "$CSV_FILE" ]] && { log WARN "No CSV to print."; return; }
  print -r -- "${C[BOLD]}──────── Per-file stats ────────${C[RESET]}"
  awk -F, 'BEGIN{fmt="%-38s %8s %3s %5s %5s %3s %8s %8s %7s %8s %10s\n"; printf fmt,"relative_path","sr","ch","inbd","flbd","c","enc_s","in_s","speed","verified","preset";}
    NR>1{gsub(/^"|"$/,"",$1); printf fmt, substr($1,1,38), $2,$3,$4,$5,$6,$7,$8,$9,$10,$11; }' "$CSV_FILE"
  print -r -- "${C[BOLD]}────────────────────────────────${C[RESET]}"
}
print_stats_detail(){
  [[ ! -s "$CSV_FILE" ]] && { log WARN "No CSV to analyze."; return; }
  print -r -- "${C[BOLD]}──────── Speed histogram (× realtime) ────────${C[RESET]}"
  awk -F, 'NR==1{next}{sp=$9+0; if(sp<=0) sp=0;
    if(sp<0.5)b0++; else if(sp<1)b1++; else if(sp<2)b2++; else if(sp<5)b3++; else b4++; total++;}
    END{printf "  <0.5× : %d\n  0.5–1×: %d\n  1–2×  : %d\n  2–5×  : %d\n  >5×   : %d\n  Total : %d\n", b0+0,b1+0,b2+0,b3+0,b4+0,total+0;}' "$CSV_FILE"
  print -r -- "${C[BOLD]}──────── Top 10 slowest (by speed ×) ────────${C[RESET]}"
  awk -F, 'NR==1{next}{sp=$9+0; path=$1; gsub(/^"|"$/,"",path); print sp "," path "," $7 "," $8 }' "$CSV_FILE" \
    | sort -t, -g -k1,1 | head -n 10 \
    | awk -F, 'BEGIN{ printf "%-6s  %-40s  %8s  %8s\n","speed","relative_path","enc_s","in_s"; }
               { printf "%-6.2f  %-40s  %8s  %8s\n",$1,substr($2,1,40),$3,$4 }'
  print -r -- "${C[BOLD]}──────────────────────────────────────────────${C[RESET]}"
}

error_summary(){ local logf="$LOG_FILE"; [[ ! -s "$logf" ]] && return
  print -r -- "${C[BOLD]}──────── Error details (from log) ────────${C[RESET]}"
  awk '
    BEGIN{in=0;file="";block=""}
    /\[.*\] \[INFO\] FFMPEG_BEGIN:/ {in=1;block="";file=$0;sub(/.*FFMPEG_BEGIN:/,"",file);next}
    in {block=block $0 "\n"}
    /\[.*\] \[INFO\] FFMPEG_END:/ {
      in=0; rc=$0; sub(/.*rc=/,"",rc);
      if (rc+0!=0) {
        print "• " file;
        n=split(block,lines,"\n");
        for(i=1;i<=n;i++){
          if (lines[i] ~ /[Ee]rror|Invalid|No such file|Unsupported|failed|cannot|Permission|sample fmt|tag.*mismatch/) {
            gsub(/^\[.*\] \[.*\] /,"",lines[i]);
            print "    " lines[i];
          }
        }
        print ""
      }
    }' "$logf"
  print -r -- "${C[BOLD]}────────────────────────────────────────────${C[RESET]}"
}

PANIC=0; PANIC_WATCHER_PID=""
kill_all_children(){ for pid in "${WORKER_PIDS[@]}"; do kill -9 "$pid" 2>/dev/null; done; pkill -P $$ 2>/dev/null; pkill -9 -f 'ffmpeg -hide_banner' 2>/dev/null; }
panic_abort(){
  PANIC=1
  if [[ ${TOTAL_FILES:-0} -gt 0 ]]; then
    flash_banner "PANIC STOP"
    print -r -- "${C[RED]}Shutting down jobs NOW…${C[RESET]}"
    print -r -- "Processed: $PROCESSED_COUNT / $TOTAL_FILES • Converted: $CONVERTED_FILES • Copied: $COPIED_FILES • Errors: $ERROR_FILES"
  fi
  kill_all_children
  print "\n${C[RED]}[ABORTED]${C[RESET]} Panic stop."
  exit 130
}
start_panic_watcher(){
  { exec 3</dev/tty
    print -r -- "\n${C[BOLD]}[KEYS] p=toggle jobs, q=panic${C[RESET]}"
    while true; do
      read -k1 -t 0.1 -u 3 key 2>/dev/null && {
        [[ "$key" == "p" || "$key" == "P" ]] && { kill -USR2 $$; print -r -- "${C[BOLD]}[KEY] p → toggle${C[RESET]}"; continue; }
        [[ "$key" == "q" || "$key" == "Q" ]] && { print -r -- "${C[BOLD]}[KEY] q → PANIC${C[RESET]}"; kill -USR1 $$; break; }
      }
      read -t 0.01 -r -u 3 line 2>/dev/null && { [[ "$line" == "exit" ]] && { kill -USR1 $$; break; }; }
      [[ $PANIC -eq 1 ]] && break
    done
    exec 3<&-
  } & PANIC_WATCHER_PID=$!
  trap 'panic_abort' INT TERM USR1
  trap 'TOGGLE_REQUESTED=1' USR2
}
stop_panic_watcher(){ [[ -n "$PANIC_WATCHER_PID" ]] && kill "$PANIC_WATCHER_PID" 2>/dev/null; trap - INT TERM USR1 USR2; }

ALT_JOBS=$MAX_PARALLEL_JOBS
TOGGLE_REQUESTED=0
TOGGLE_TO_SINGLE_AT=0
PROCESSED_COUNT=0

SHORT_THRESH=2.0
SHORT_THRESH_MS=$(awk -v t="$SHORT_THRESH" 'BEGIN{printf("%d", t*1000)}')

SAMPLES_PER_SUBDIR=10
STREAK_SHORT=0; STREAK_LONG=0
SHORT_STREAK_TRIGGER=10
LONG_STREAK_RESTORE=10

toggle_jobs(){
  if (( MAX_PARALLEL_JOBS > 1 )); then
    ALT_JOBS=$MAX_PARALLEL_JOBS; MAX_PARALLEL_JOBS=1; TOGGLE_TO_SINGLE_AT=$(date +%s)
    flash_banner "JOBS: -j 1 (single)"; log STEP "Jobs toggled: now -j 1 (single)"
  else
    MAX_PARALLEL_JOBS=${ALT_JOBS:-2}; TOGGLE_TO_SINGLE_AT=0
    flash_banner "JOBS: -j $MAX_PARALLEL_JOBS (parallel)"; log STEP "Jobs toggled: now -j $MAX_PARALLEL_JOBS (parallel)"
  fi
}
maybe_auto_restore(){
  (( TOGGLE_TO_SINGLE_AT > 0 )) || return
  local now=$(date +%s); (( now - TOGGLE_TO_SINGLE_AT >= 30 )) || return
  local avg=0; if (( CONVERTED_FILES > 0 )); then avg=$(awk -v a="$TOTAL_INPUT_AUDIO_SEC" -v n="$CONVERTED_FILES" 'BEGIN{ if(n>0) printf("%.2f", a/n); else print 0 }'); fi
  local remain=$(( TOTAL_FILES - PROCESSED_COUNT ))
  if (( PROCESSED_COUNT >= 20 )) && { awk -v a="$avg" 'BEGIN{exit !(a>=4)}' || (( remain >= 100 )); }; then
    MAX_PARALLEL_JOBS=${ALT_JOBS:-2}; TOGGLE_TO_SINGLE_AT=0
    flash_banner "JOBS AUTO-RESTORE: -j $MAX_PARALLEL_JOBS"; log STEP "Auto-restore: jobs back to -j $MAX_PARALLEL_JOBS"
  else
    TOGGLE_TO_SINGLE_AT=$now
  fi
}
sample_dir_and_set_jobs(){
  local d="$1" max="$SAMPLES_PER_SUBDIR" n=0 short=0 f
  command -v find >/dev/null 2>/dev/null || return
  while IFS= read -r -d '' f; do
    local dr; dr=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 -- "$f" 2>/dev/null)
    [[ -z "$dr" ]] && continue
    awk -v dd="$dr" 'BEGIN{exit !(dd>0)}' || continue
    (( n++ )); awk -v dd="$dr" -v th="$SHORT_THRESH" 'BEGIN{exit !(dd<=th)}' && (( short++ ))
    (( n>=max )) && break
  done < <(find "$d" -maxdepth 1 -type f \( -iname "*.wav" -o -iname "*.aif" -o -iname "*.aiff" -o -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.mp3" -o -iname "*.flac" \) -print0)
  (( n<5 )) && return
  if awk -v s="$short" -v t="$n" 'BEGIN{exit !((t>0)&&(s*100/t>=70))}'; then
    if (( MAX_PARALLEL_JOBS>1 )); then ALT_JOBS=$MAX_PARALLEL_JOBS; MAX_PARALLEL_JOBS=1; TOGGLE_TO_SINGLE_AT=$(date +%s); flash_banner "DIR HEURISTIC: -j 1 for ${d:t}"; log STEP "Dir heuristic: many one-shots in ${d:t} → -j 1"; fi
  else
    if (( MAX_PARALLEL_JOBS==1 )); then MAX_PARALLEL_JOBS=${ALT_JOBS:-2}; TOGGLE_TO_SINGLE_AT=0; flash_banner "DIR HEURISTIC: -j $MAX_PARALLEL_JOBS for ${d:t}"; log STEP "Dir heuristic: fewer one-shots in ${d:t} → -j $MAX_PARALLEL_JOBS"; fi
  fi
}

get_audio_properties(){ local file="$1" probe sr ch sf bd
  probe=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,sample_fmt,bits_per_raw_sample -print_format json -- "$file" 2>/dev/null)
  [[ -z "$probe" ]] && { echo "44100 2 s16 16"; return; }
  sr=$(echo "$probe"|grep -m1 '"sample_rate"'|sed 's/.*: *"\?\([0-9]*\)"\?.*/\1/')
  ch=$(echo "$probe"|grep -m1 '"channels"'|sed 's/.*: *\([0-9]*\).*/\1/')
  sf=$(echo "$probe"|grep -m1 '"sample_fmt"'|sed -E 's/.*: *"([^"]+)".*/\1/')
  bd=$(echo "$probe"|grep -m1 '"bits_per_raw_sample"'|sed 's/.*: *"\?\([0-9]*\)"\?.*/\1/')
  : ${sr:=44100}; : ${ch:=2}; : ${sf:=s16}; : ${bd:=16}; echo "$sr $ch $sf $bd"
}
get_duration_ms(){ local f="$1" d; d=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 -- "$f" 2>/dev/null); [[ -z "$d" ]] && { echo 0; return; }; awk -v x="$d" 'BEGIN{printf("%d", x*1000)}'; }
is_audio_file(){ local e=$(lower_ext "$1")
  local a=(mp3 wav aac m4a ogg opus wma aiff aif au ra 3gp amr ac3 dts mp2 mka webm ape wv tta tak flac)
  for x in "${a[@]}"; do [[ "$e" == "$x" ]] && return 0; done
  ffprobe -v error -show_entries stream=codec_type -select_streams a -- "$1" &>/dev/null && return 0
  return 1
}
is_flac_file(){ [[ "$(lower_ext "$1")" == "flac" ]]; }
is_mp3_file(){  [[ "$(lower_ext "$1")" == "mp3"  ]]; }

extract_loops_and_cues(){ local wav="$1" json_out="$2"
  local loop_start="" loop_end="" loop_count="" cue_points=()
  if command -v sox >/dev/null 2>/dev/null; then
    local sx; sx=$(sox --i -a -- "$wav" 2>/dev/null)
    if echo "$sx"|grep -qi 'Loop'; then
      loop_start=$(echo "$sx"|sed -n 's/.*[Ll]oop[^0-9]*\([0-9]\+\).*/\1/p'|head -n1)
      loop_end=$(  echo "$sx"|sed -n 's/.*[Ll]oop.*[eE]nd[^0-9]*\([0-9]\+\).*/\1/p'|head -n1)
      loop_count=$(echo "$sx"|grep -ci '[Ll]oop')
    fi
    if echo "$sx"|grep -qi 'Cue'; then
      local cues; cues=$(echo "$sx"|sed -n 's/.*[Cc]ue[^0-9]*\([0-9]\+\).*/\1/p'); [[ -n "$cues" ]] && cue_points=(${=cues})
    fi
  fi
  { printf '{'; local first=1
    [[ -n "$loop_start" ]] && { printf '"LOOP_START":%s' "$loop_start"; first=0; }
    [[ -n "$loop_end"   ]] && { ((first==0)) && printf ','; printf '"LOOP_END":%s' "$loop_end"; first=0; }
    [[ -n "$loop_count" ]] && { ((first==0)) && printf ','; printf '"LOOP_COUNT":%s' "$loop_count"; first=0; }
    if (( ${#cue_points[@]} > 0 )); then ((first==0)) && printf ','; printf '"CUE_POINTS":['; local i=1; while (( i <= ${#cue_points[@]} )); do printf '%s' "${cue_points[$i]}"; (( i < ${#cue_points[@]} )) && printf ','; ((i++)); done; printf ']'; fi
    printf '}\n'; } > "$json_out"
  [[ "$(wc -c <"$json_out")" -le 4 ]] && { rm -f "$json_out"; return 1; }
  return 0
}
inject_loops_and_cues_into_flac(){ local flac="$1" json="$2"
  [[ ! -s "$json" ]] && return 0
  if ! command -v metaflac >/dev/null 2>/dev/null; then log WARN "metaflac not available; cannot inject loop/cue tags into ${flac:t}"; return 0; fi
  local LOOP_START LOOP_END LOOP_COUNT; local -a CUES
  LOOP_START=$(sed -n 's/.*"LOOP_START":[[:space:]]*\([0-9]\+\).*/\1/p' "$json")
  LOOP_END=$(  sed -n 's/.*"LOOP_END":[[:space:]]*\([0-9]\+\).*/\1/p' "$json")
  LOOP_COUNT=$(sed -n 's/.*"LOOP_COUNT":[[:space:]]*\([0-9]\+\).*/\1/p' "$json")
  local cues; cues=$(sed -n 's/.*"CUE_POINTS":[[:space:]]*\[\(.*\)\].*/\1/p' "$json"|tr -d ' '|tr ',' ' '); [[ -n "$cues" ]] && CUES=(${=cues})
  metaflac --remove-tag=LOOP_START --remove-tag=LOOP_END --remove-tag=LOOP_COUNT -- "$flac" 2>/dev/null
  [[ -n "$LOOP_START" ]] && metaflac --set-tag="LOOP_START=$LOOP_START" -- "$flac" 2>/dev/null
  [[ -n "$LOOP_END"   ]] && metaflac --set-tag="LOOP_END=$LOOP_END"     -- "$flac" 2>/dev/null
  [[ -n "$LOOP_COUNT" ]] && metaflac --set-tag="LOOP_COUNT=$LOOP_COUNT" -- "$flac" 2>/dev/null
  local idx=1 p
  while metaflac --show-tag="CUE_POINT_$idx" -- "$flac" >/dev/null 2>&1; do metaflac --remove-tag="CUE_POINT_$idx" -- "$flac" >/dev/null 2>&1 || break; ((idx++)); done
  idx=1; for p in "${CUES[@]}"; do [[ -n "$p" ]] && metaflac --set-tag="CUE_POINT_${idx}=$p" -- "$flac" >/dev/null 2>&1; ((idx++)); done
  log OK "Loop/cue tags injected into ${flac:t}"
}

verify_flac(){ local f="$1"; if command -v flac &>/dev/null; then flac -t -- "$f" &>/dev/null; else ffmpeg -nostdin -v error -i "$f" -f null - &>/dev/null; fi; }

ffmpeg_ms_from_hms(){ awk -F '[:\\.]' '{ ms=$1*3600000+$2*60000+$3*1000+($4?substr($4,1,3):0); printf("%d",ms) }'; }

convert_audio_file(){ local infile="$1" outfile="$2" rel="$3"
  setopt LOCAL_OPTIONS NO_GLOB
  [[ $PANIC -eq 1 ]] && return 1
  [[ ! -r "$infile" ]] && { log ERROR "Unreadable file: $infile"; return 1; }
  local tmp="${outfile}.part"; mkdir -p -- "${outfile:h}"

  read sr ch sf bd <<<"$(get_audio_properties "$infile")"
  local flac_sf=""; [[ -n "$bd" && "$bd" -le 16 ]] && flac_sf="s16"; [[ -z "$flac_sf" && -n "$bd" && "$bd" -le 24 ]] && flac_sf="s24"
  local dur_ms=$(get_duration_ms "$infile") dur_sec=$(( dur_ms/1000 ))

  _logfile INFO "FFMPEG_BEGIN:$infile"
  _logfile DEBUG "convert: $infile -> $outfile (sr=$sr ch=$ch sf=$sf bits=$bd → ${flac_sf:-auto} dur=${dur_sec}s)"

  local -a cmd=(nice -n $NICE_LEVEL)
  command -v ionice >/dev/null 2>/dev/null && cmd+=(ionice -c 2 -n 7)

  local progress_fifo="" have_progress=0
  if (( MAX_PARALLEL_JOBS==1 && dur_ms>0 )); then progress_fifo="$(mktemp -u)"; mkfifo "$progress_fifo" || progress_fifo=""; [[ -n "$progress_fifo" ]] && have_progress=1; fi

  cmd+=(ffmpeg -nostdin -hide_banner -y -i "$infile" -map '0:a?' -map_metadata 0 -map_chapters 0 -c:a flac -compression_level "$FLAC_COMPRESSION" -ar "$sr" -ac "$ch")
  [[ -n "$flac_sf" ]] && cmd+=( -sample_fmt "$flac_sf" )
  (( have_progress )) && cmd+=( -nostats -progress "$progress_fifo" ) || cmd+=( -loglevel error )
  cmd+=( -- "$tmp" )

  local prog_pid=""
  if (( have_progress )); then
    { local last_us=0 pct=0
      while read -r line; do
        [[ $PANIC -eq 1 ]] && break
        case "$line" in
          out_time_ms=*) last_us="${line#out_time_ms=}"; [[ "$last_us" =~ ^[0-9]+$ ]] || continue;;
          out_time=*)    last_us=$(( $(ffmpeg_ms_from_hms <<<"${line#out_time=}") * 1000 ));;
          progress=end)  draw_bar 100 100 40 "encode: ${infile:t}";;
        esac
        if (( dur_ms>0 && last_us>0 )); then
          pct=$(( last_us/1000*100/dur_ms )); (( pct>100 ))&&pct=100
          draw_bar $pct 100 40 "encode: ${infile:t}"
        fi
      done <"$progress_fifo"
    } & prog_pid=$!
  fi

  local t0=$(now_ms)
  { "${cmd[@]}" 2>>"$LOG_FILE"; } & local encpid=$!
  while kill -0 "$encpid" 2>/dev/null; do
    [[ $PANIC -eq 1 ]] && { kill "$encpid" 2>/dev/null; pkill -9 -P "$encpid" 2>/dev/null; }
    sleep 0.1
  done
  wait "$encpid"; local rc=$?
  _logfile INFO "FFMPEG_END:$infile rc=$rc"
  [[ -n "$prog_pid" ]] && wait "$prog_pid" 2>/dev/null
  [[ -n "$progress_fifo" ]] && rm -f "$progress_fifo"
  (( have_progress )) && { draw_bar 100 100 40 "encode: ${infile:t}"; newline; }

  if (( rc!=0 )); then
    local last_err; last_err=$(tail -n 120 -- "$LOG_FILE"|grep -E "error|Invalid|No such file|Unsupported|failed|cannot|Permission|sample fmt|tag.*mismatch" | tail -n 1)
    log ERROR "ffmpeg failed: ${infile:t}${last_err:+ — $last_err}"
    rm -f -- "$tmp"; return 1
  fi
  [[ $PANIC -eq 1 ]] && { rm -f -- "$tmp"; return 1; }

  if [[ "$VERIFY_MODE" == "true" ]]; then
    spinner_run "verify ${outfile:t}" verify_flac "$tmp" || { rm -f -- "$tmp"; log WARN "Verify failed: ${infile:t}"; return 1; }
  fi

  mv -f -- "$tmp" "$outfile"
  touch -r "$infile" "$outfile"
  log OK "Converted: ${infile:t} → ${outfile:t}"
  (( TOTAL_INPUT_AUDIO_SEC += dur_sec ))

  local out_bits=""; [[ "$flac_sf" == "s16" ]] && out_bits=16; [[ "$flac_sf" == "s24" ]] && out_bits=24
  local enc_ms=$(( $(now_ms)-t0 )); (( enc_ms<1 ))&&enc_ms=1
  local enc_s=$(awk -v x="$enc_ms" 'BEGIN{printf("%.3f", x/1000)}')
  local spd=$(awk -v ain="$dur_sec" -v e="$enc_ms" 'BEGIN{ if(e>0) printf("%.2f", ain/(e/1000)); else print "inf" }')
  csv_append "$(printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s' "$(csv_escape "$rel")" "$sr" "$ch" "$bd" "${out_bits:-}" "$FLAC_COMPRESSION" "$enc_s" "$dur_sec" "$spd" "yes" "$PRESET_USED")"

  if [[ "${infile:l}" == *.wav ]]; then
    local loop_json="${outfile}.loop.json"
    if extract_loops_and_cues "$infile" "$loop_json"; then inject_loops_and_cues_into_flac "$outfile" "$loop_json"; fi
  fi

  local tnow=$(check_temp_c); (( tnow>PEAK_TEMP_C )) && PEAK_TEMP_C=$tnow
  return 0
}

copy_file(){ local src="$1" dst="$2"; mkdir -p -- "${dst:h}"; cp -p -- "$src" "$dst" 2>>"$LOG_FILE" && log INFO "Copied: ${src:t}" || { log ERROR "Copy failed: ${src:t}"; return 1; } }

prune_workers(){ local -a keep=() pid; for pid in "${WORKER_PIDS[@]}"; do if kill -0 "$pid" 2>/dev/null; then keep+=("$pid"); else wait "$pid" 2>/dev/null; fi; done; WORKER_PIDS=("${keep[@]}"); }
wait_for_slot(){ prune_workers; while (( ${#WORKER_PIDS[@]} >= MAX_PARALLEL_JOBS )); do [[ $PANIC -eq 1 ]] && return; sleep 0.25; prune_workers; done; }
spawn_worker(){ "$@" & local pid=$!; WORKER_PIDS+=("$pid"); wait_for_slot; }

process_single_file(){ local infile="$1"
  [[ $PANIC -eq 1 ]] && return 1
  local rel="${infile#${INPUT_DIR}/}"; [[ -z "$rel" || "$rel" == "$infile" || "$rel" == /* ]] && rel="${infile:t}"
  local out="$OUTPUT_DIR/$rel"
  local tnow=$(check_temp_c); (( tnow>PEAK_TEMP_C )) && PEAK_TEMP_C=$tnow

  if is_flac_file "$infile" || is_mp3_file "$infile"; then
    if [[ "$IN_PLACE_MODE" == "true" ]]; then ((SKIPPED_FILES++)); log INFO "Skip ${infile:t} (in-place)"
    else copy_file "$infile" "$out" && ((COPIED_FILES++)) || ((ERROR_FILES++)); fi
    return 0
  fi

  if is_audio_file "$infile"; then
    out="${out%.*}.flac"
    if [[ "$DRY_RUN" == "true" ]]; then log INFO "[DRY] Convert ${infile:t} -> ${out:t}"; return 0; fi
    if convert_audio_file "$infile" "$out" "$rel"; then
      ((CONVERTED_FILES++))
      if [[ "$IN_PLACE_MODE" == "true" && "$out" != "$infile" ]]; then rm -f -- "$infile"; fi
      return 0
    else
      ((ERROR_FILES++)); return 1
    fi
  fi

  if [[ "$IN_PLACE_MODE" == "true" ]]; then ((SKIPPED_FILES++)); log DEBUG "Skip non-audio (in-place): ${infile:t}"
  else if [[ "$DRY_RUN" == "true" ]]; then log INFO "[DRY] Copy non-audio ${infile:t}"
       else copy_file "$infile" "$out" && ((COPIED_FILES++)) || ((ERROR_FILES++)); fi
  fi
}

ALT_JOBS=$MAX_PARALLEL_JOBS
TOGGLE_REQUESTED=0
TOGGLE_TO_SINGLE_AT=0
PROCESSED_COUNT=0
LAST_DIR=""
STREAK_SHORT=0; STREAK_LONG=0

toggle_jobs(){ if (( MAX_PARALLEL_JOBS>1 )); then ALT_JOBS=$MAX_PARALLEL_JOBS; MAX_PARALLEL_JOBS=1; TOGGLE_TO_SINGLE_AT=$(date +%s); flash_banner "JOBS: -j 1 (single)"; else MAX_PARALLEL_JOBS=${ALT_JOBS:-2}; TOGGLE_TO_SINGLE_AT=0; flash_banner "JOBS: -j $MAX_PARALLEL_JOBS (parallel)"; fi }
maybe_auto_restore(){ (( TOGGLE_TO_SINGLE_AT>0 )) || return; local now=$(date +%s); (( now-TOGGLE_TO_SINGLE_AT>=30 )) || return; local avg=0; (( CONVERTED_FILES>0 )) && avg=$(awk -v a="$TOTAL_INPUT_AUDIO_SEC" -v n="$CONVERTED_FILES" 'BEGIN{ if(n>0) printf("%.2f", a/n); else print 0 }'); local remain=$(( TOTAL_FILES-PROCESSED_COUNT )); if (( PROCESSED_COUNT>=20 )) && { awk -v a="$avg" 'BEGIN{exit !(a>=4)}' || (( remain>=100 )); }; then MAX_PARALLEL_JOBS=${ALT_JOBS:-2}; TOGGLE_TO_SINGLE_AT=0; flash_banner "JOBS AUTO-RESTORE: -j $MAX_PARALLEL_JOBS"; else TOGGLE_TO_SINGLE_AT=$now; fi }
sample_dir_and_set_jobs(){ local d="$1" max=10 n=0 short=0 f; command -v find >/dev/null 2>/dev/null || return
  while IFS= read -r -d '' f; do local dr; dr=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 -- "$f" 2>/dev/null); [[ -z "$dr" ]] && continue; awk -v dd="$dr" 'BEGIN{exit !(dd>0)}' || continue; (( n++ )); awk -v dd="$dr" -v th="2.0" 'BEGIN{exit !(dd<=th)}' && (( short++ )); (( n>=max )) && break; done < <(find "$d" -maxdepth 1 -type f \( -iname "*.wav" -o -iname "*.aif" -o -iname "*.aiff" -o -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.mp3" -o -iname "*.flac" \) -print0)
  (( n<5 )) && return
  if awk -v s="$short" -v t="$n" 'BEGIN{exit !((t>0)&&(s*100/t>=70))}'; then if (( MAX_PARALLEL_JOBS>1 )); then ALT_JOBS=$MAX_PARALLEL_JOBS; MAX_PARALLEL_JOBS=1; TOGGLE_TO_SINGLE_AT=$(date +%s); flash_banner "DIR HEURISTIC: -j 1 for ${d:t}"; fi
  else if (( MAX_PARALLEL_JOBS==1 )); then MAX_PARALLEL_JOBS=${ALT_JOBS:-2}; TOGGLE_TO_SINGLE_AT=0; flash_banner "DIR HEURISTIC: -j $MAX_PARALLEL_JOBS for ${d:t}"; fi; fi }

process_all_files(){
  local -a file_list
  file_list=( ${INPUT_DIR}/**/*(.) )
  file_list=( ${file_list:#${LOG_DIR}/*} )
  [[ -n "$OUTPUT_DIR" ]] && file_list=( ${file_list:#${OUTPUT_DIR}/*} )

  TOTAL_FILES=${#file_list}; _logfile INFO "Files found: ${TOTAL_FILES}"
  (( TOTAL_FILES==0 )) && { log WARN "No files under ${INPUT_DIR}"; return 0; }

  start_panic_watcher
  local idx=0
  for f in "${file_list[@]}"; do
    ((idx++)); PROCESSED_COUNT=$idx
    draw_bar "$idx" "$TOTAL_FILES" 40 "batch"
    [[ $PANIC -eq 1 ]] && break

    (( TOGGLE_REQUESTED )) && { toggle_jobs; TOGGLE_REQUESTED=0; }
    maybe_auto_restore

    local curdir="${f:h}"
    if [[ "$curdir" != "$LAST_DIR" ]]; then
      LAST_DIR="$curdir"
      sample_dir_and_set_jobs "$curdir"
      STREAK_SHORT=0; STREAK_LONG=0
    fi

    local dur_ms=$(get_duration_ms "$f")
    if (( dur_ms>0 && dur_ms<=SHORT_THRESH_MS )); then
      (( STREAK_SHORT++ )); STREAK_LONG=0
      if (( MAX_PARALLEL_JOBS>1 && STREAK_SHORT>=10 )); then toggle_jobs; fi
    else
      (( STREAK_LONG++ )); STREAK_SHORT=0
      if (( MAX_PARALLEL_JOBS==1 && STREAK_LONG>=10 )); then toggle_jobs; fi
    fi

    if (( MAX_PARALLEL_JOBS>1 )); then
      spawn_worker process_single_file "$f"
    else
      process_single_file "$f"
    fi
  done

  for pid in "${WORKER_PIDS[@]}"; do kill -0 "$pid" 2>/dev/null && wait "$pid"; done
  stop_panic_watcher
  newline
  [[ $PANIC -eq 1 ]] && panic_abort
}

# ---------- CLI ----------
typeset -a input output compress jobs   # <<< predeclare arrays (fixes input[2] crash)
zparseopts -D -E \
  h=help -help=help d=dry_run -dry-run=dry_run s=skip_maint -skip-maint=skip_maint \
  n=no_verify -no-verify=no_verify v=verbose -verbose=verbose \
  S=stats_flag -stats=stats_flag D=details_flag -stats-detail=details_flag \
  y=assume_yes -assume-yes=assume_yes i:=input -input:=input o:=output -output:=output \
  c:=compress -compress:=compress j:=jobs -jobs:=jobs

[[ -n "$verbose" ]] && VERBOSE=1
[[ -n "$dry_run" ]] && DRY_RUN=true
[[ -n "$skip_maint" ]] && SKIP_MAINT=true
[[ -n "$no_verify" ]] && VERIFY_MODE=false
[[ -n "$stats_flag" ]] && PRINT_STATS=true
[[ -n "$details_flag" ]] && PRINT_STATS_DETAIL=true && PRINT_STATS=true
[[ -n "$assume_yes" ]] && ASSUME_YES=true
(( ${#input[@]}   >= 2 )) && INPUT_DIR="${input[2]}"
(( ${#output[@]}  >= 2 )) && OUTPUT_FOLDER_NAME="${output[2]}"
if (( ${#compress[@]} >= 2 )); then FLAC_COMPRESSION="${compress[2]}"; CLI_COMP_SET=1; fi
if (( ${#jobs[@]}     >= 2 )); then MAX_PARALLEL_JOBS="${jobs[2]}"; CLI_JOBS_SET=1; fi

log STEP "Welcome to FLAC Converter Pro v${VERSION}"

if [[ -z "$dry_run" ]]; then ask_yes_no "Enable DRY-RUN mode (no changes)?" "N"; [[ "$REPLY_YN" == "Y" ]] && DRY_RUN=true; fi
if [[ -z "$skip_maint" ]]; then ask_yes_no "Default to running package maintenance when needed?" "Y"; [[ "$REPLY_YN" == "N" ]] && SKIP_MAINT=true; fi

log STEP "Checking tools…"; check_or_install_deps || { log ERROR "Dependency step failed; aborting."; exit 1; }
log STEP "Detecting power/thermals…"; apply_preset "$(decide_preset)"
log INFO "Using: jobs=$MAX_PARALLEL_JOBS comp=$FLAC_COMPRESSION nice=$NICE_LEVEL (preset=$PRESET_USED)"
if [[ -r /proc/cpuinfo ]]; then model_hint=$(grep -m1 -E 'Hardware|Model|vendor_id' /proc/cpuinfo|sed 's/.*:\s*//'); log INFO "CPU hint: ${model_hint:-unknown}; cores=$(nproc 2>/dev/null || echo '?')"; fi

select_mode_strict(){
  echo; echo "${C[BOLD]}Select conversion mode:${C[RESET]}"
  echo "  1) Safe Mode (mirror into: ${OUTPUT_FOLDER_NAME})"
  echo "  2) In-Place (replace source audio files; skip flac/mp3)"
  echo "  3) Archive (safe + timestamped backup)"
  local choice=""
  while true; do
    printf "Choice (1-3) [1]: "; read -r choice; [[ -z "$choice" ]] && choice="1"
    case "$choice" in
      1|2|3) break;;
      *) print -r -- "${C[YELLOW]}Please type 1, 2, or 3${C[RESET]}";;
    esac
  done
  case "$choice" in
    2) IN_PLACE_MODE=true;  OUTPUT_DIR="${INPUT_DIR}" ;;
    3) IN_PLACE_MODE=false; PRESERVE_ORIGINALS=true; OUTPUT_DIR="${INPUT_DIR}/flac_archive_${DATE_STAMP}" ;;
    *) IN_PLACE_MODE=false; OUTPUT_DIR="${INPUT_DIR}/${OUTPUT_FOLDER_NAME}" ;;
  esac
}
if [[ "$ASSUME_YES" != "true" && "$DRY_RUN" != "true" ]]; then
  select_mode_strict
else
  IN_PLACE_MODE=false; OUTPUT_DIR="${INPUT_DIR}/${OUTPUT_FOLDER_NAME}"
fi
[[ "$IN_PLACE_MODE" == "true" ]] && log WARN "In-place mode: existing .flac/.mp3 left as-is." || mkdir -p -- "$OUTPUT_DIR"

CSV_FILE="${OUTPUT_DIR}/flac_stats_${DATE_STAMP}.csv"; csv_init
_logfile INFO "Started v${VERSION}"; _logfile INFO "System: $(uname -a)"

if [[ "$ASSUME_YES" != "true" && "$DRY_RUN" != "true" ]]; then
  ask_yes_no "Process ${INPUT_DIR} into ${OUTPUT_DIR} ?" "Y" || { log INFO "Cancelled."; exit 0; }
fi

process_all_files

END_EPOCH=$(date +%s); WALL=$(( END_EPOCH - START_EPOCH )); (( WALL<0 ))&&WALL=0
fmt_hms(){ local s="$1"; printf "%02d:%02d:%02d" $((s/3600)) $(((s%3600)/60)) $((s%60)); }
AVG_RT="n/a"; (( WALL>0 )) && AVG_RT=$(awk -v ain="$TOTAL_INPUT_AUDIO_SEC" -v wall="$WALL" 'BEGIN{ if(wall>0) printf("%.2fx", ain/wall); else print "n/a"; }')
(( PEAK_TEMP_C<0 )) && PEAK_TEMP_C=$(check_temp_c)

newline; print -r -- "${C[BOLD]}──────── Summary ────────${C[RESET]}"
printf "%-24s : %s\n" "Preset used" "$PRESET_USED"
printf "%-24s : %s\n" "Jobs / Compression" "$MAX_PARALLEL_JOBS / $FLAC_COMPRESSION"
printf "%-24s : %s\n" "Verify outputs" "$([[ "$VERIFY_MODE" == "true" ]] && echo yes || echo no)"
printf "%-24s : %s\n" "Total files" "$TOTAL_FILES"
printf "%-24s : %s\n" "Converted / Copied" "$CONVERTED_FILES / $COPIED_FILES"
printf "%-24s : %s\n" "Skipped / Errors" "$SKIPPED_FILES / $ERROR_FILES"
printf "%-24s : %s\n" "Total input audio" "$(awk -v s="$TOTAL_INPUT_AUDIO_SEC" 'BEGIN{printf("%.0f s (%.2f h)", s, s/3600)}')"
printf "%-24s : %s\n" "Wall time" "$(fmt_hms "$WALL")"
printf "%-24s : %s\n" "Avg encode speed" "$AVG_RT realtime"
printf "%-24s : %s\n" "Peak temperature" "$PEAK_TEMP_C °C"
printf "%-24s : %s\n" "CSV stats" "$CSV_FILE"
printf "%-24s : %s\n" "Log file" "$LOG_FILE"
print -r -- "${C[BOLD]}──────────────────────────${C[RESET]}"; newline
[[ $ERROR_FILES -gt 0 ]] && error_summary
log INFO "Done. total=${TOTAL_FILES} converted=${CONVERTED_FILES} copied=${COPIED_FILES} skipped=${SKIPPED_FILES} errors=${ERROR_FILES}"
cat <<EOF
${C[GREEN]}Conversion finished${C[RESET]}
Total: ${TOTAL_FILES}
Converted: ${CONVERTED_FILES}
Copied: ${COPIED_FILES}
Skipped: ${SKIPPED_FILES}
Errors: ${ERROR_FILES}
CSV: $CSV_FILE
Log: ${LOG_FILE}
EOF
exit 0
