#!/usr/bin/env bash
# Whole stack: Isaac Sim (container) + telemetry bridge + MPPI + RViz (host). Ctrl-C stops all.
#   ./run.sh                          vanilla MPPI
#   CONTROLLER=modifiers/x.py ./run.sh  another single-file controller
#   HEADLESS=true NO_RVIZ=1 ./run.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LOGS="$ROOT/logs"; mkdir -p "$LOGS"
CONTROLLER="${CONTROLLER:-modifiers/vanilla_mppi.py}"
export PROJECT_NAME="${PROJECT_NAME:-simenvbtuuv}"  # container image/name prefix
export HEADLESS="${HEADLESS:-false}"

set +u; source /opt/ros/jazzy/setup.bash; set -u
export ROS_LOG_DIR="$LOGS/ros"
# rviz2 crashes on the GTK variables the VS Code snap terminal sets
RVIZ_ENV=(env -u GTK_PATH -u GIO_MODULE_DIR -u GTK_EXE_PREFIX -u LOCPATH -u GSETTINGS_SCHEMA_DIR -u GTK_IM_MODULE_FILE)

PIDS=()
cleanup() {
  trap - INT TERM EXIT
  kill "${PIDS[@]}" 2>/dev/null
  podman stop -t 5 "$PROJECT_NAME-sim" >/dev/null 2>&1
  wait 2>/dev/null
}
trap cleanup INT TERM EXIT

# Isaac Sim, actions from UDP :15000, telemetry to UDP :15010. `script` gives the container its TTY.
(cd "$ROOT/marine-gym-frl" && script -qfec \
  "./run-container.sh sim bash release/scripts/00_open_hover_vel_ros2_joystick.sh" /dev/null) \
  > "$LOGS/sim.log" 2>&1 &
PIDS+=($!)

# UDP :15010 -> /bluerov/* topics
python3 "$ROOT/marine-gym-frl/scripts/ros2_udp_telemetry_publisher.py" > "$LOGS/telemetry.log" 2>&1 &
PIDS+=($!)

# Controller: /bluerov/* -> UDP :15000 (+ /fossen/* and /mppi_rollouts)
(cd "$ROOT/fossen-diff" && PYTHONPATH=/opt/ros/jazzy/lib/python3.12/site-packages uv run python "$CONTROLLER") \
  > "$LOGS/controller.log" 2>&1 &
PIDS+=($!)

if [ -z "${NO_RVIZ:-}" ]; then
  (cd "$ROOT/fossen-diff" && "${RVIZ_ENV[@]}" rviz2 -d fossen.rviz) > "$LOGS/rviz.log" 2>&1 &
  PIDS+=($!)
fi

echo "running; logs in $LOGS (tail -f logs/sim.log). Ctrl-C to stop."
wait -n "${PIDS[@]}"
echo "a process exited; stopping the stack"
