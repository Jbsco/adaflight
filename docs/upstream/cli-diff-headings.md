# A diff prints flight plan, beeper and feature lines before their section headings

Betaflight 2026.12 (master as of 2026-10-25). Findings F170, F171 and F172, `DESIGN.md` D181. Not reported upstream.

## Betaflight

A diff prints a section's heading before the first line the section prints, through a heading request that each printed line makes. The flight plan printer makes no request for its `waypoint clear` line and requests the heading only for a waypoint within the default plan's count. The default plan is empty, so a diff prints the flight plan's lines under whatever heading came last. Observed in the command line oracle: `diff` prints `waypoint clear` and `waypoint insert 0 ...` under `# vtxtable`. The beeper printer prints a changed condition's default line before it requests the heading, so `diff master defaults` prints `#beeper RX_LOST_LANDING` after the last `smix` line, then `# beeper`. The feature printer requests the heading for a feature disabled from an enabled default and for an enabled feature's own line, but prints the default line of a feature enabled from a disabled default without a request, so `diff hardware defaults` prints `#feature -OPTICALFLOW`, `#feature -LED_STRIP` and `#feature -ESC_SENSOR` above `# feature`.

## adaflight

Each section heading precedes the first line the section prints: the flight plan requests it for its clear line and for every waypoint line, the beeper printer requests it before a changed condition's default line, and the feature printer requests it whenever a feature differs from its default, before either default line. The command line vectors with diffs were recorded from a host build of Betaflight's command line with the same requests.

## Proposed change for Betaflight

Request the heading before the `waypoint clear` line and before every waypoint line, move the beeper heading request before the default line, and request the feature heading with the feature's difference from its default in both loops.
