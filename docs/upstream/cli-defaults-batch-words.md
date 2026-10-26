# The defaults and batch commands take parts of their words

Betaflight 2026.12 (master as of 2026-10-25). Findings F178 and F180, `DESIGN.md` D185 and D189. Not reported upstream.

## Betaflight

The defaults command matches each word with a substring search, so a word that only contains group_id or nosave, such as xgroup_idx, passes. It reads the group number into sixteen bits, so 65550 names group 14, the PID profiles, and -1 names group 65535, and a number no group has prints the reset message and changes nothing. Observed in the command line oracle: `defaults GROUP_ID 65550 nosave` prints `# resetting group 14 to defaults` and resets the PID profiles. The batch command compares the first five characters of its option with start and the first three with end, so `batch startx` and `batch end now` pass. A second `batch start` inside an open batch keeps the batch's error, so an error before it still ends the batch with the error line.

## adaflight

The defaults command takes group_id and nosave as whole words in any case and refuses a group number outside 1 to 65535. The batch command takes start and end as whole words in any case, and every start clears the batch's error. The defaults and batch vectors were recorded from a host build of Betaflight's command line with the same comparisons.

## Proposed change for Betaflight

Compare the words with a whole-word comparison, read the group number into a wider type and refuse values outside 1 to 65535, and clear the batch's error on every start.
