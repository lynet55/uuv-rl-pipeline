# Pipeline for training and evaluating Sonar only policy
- differentiable fossen dynamics
- MarineGym environment 

## Run

Whole stack (Isaac Sim in its container, telemetry bridge, MPPI, rviz) from the repo root, Ctrl-C stops it:
```bash
./run.sh                                        # logs in logs/
CONTROLLER=modifiers/<other>.py ./run.sh        # another single-file controller in fossen-diff/
HEADLESS=true NO_RVIZ=1 ./run.sh
```

```
Isaac Sim --UDP:15010--> telemetry bridge --> /bluerov/{odom,goal,sonar/scan,map} --> controller
Isaac Sim <--UDP:15000-- {"action": [u, v, w, r] in [-1, 1]}, body FLU / VEL_MAX <-- controller
```

Controllers in `fossen-diff/modifiers/` are algorithm only (`Observation -> Command`);
ROS topics, rviz markers and the sim's UDP action port live in `fossen-diff/ros_io.py`.

Manual control instead (from `marine-gym-frl/`): `bash release/scripts/00_ros2_bridges.sh` and `bash release/scripts/00_ros2_keyboard_joy.sh`.
