# The review board: rendering /evolve's PROPOSE phase as a page

`/evolve` ends in a single approval surface. When a run is small, a chat table works. When a run
is large, the chat table stops working, and the failure is not obvious from inside it.

This document describes the alternative: rendering the PROPOSE phase as a self-contained HTML
page. It also records the design constraints that produced it, because most of them were learned
by getting them wrong first.

## The problem a table cannot solve

A backlog of 145 candidates collapses into roughly 36 proposed writes. Presented as a chat table
that is 36 rows wide, and each row has to carry enough for a human to actually judge it: what the
artifact would do, why the confidence is what it is, where it lands, what evidence backs it.

That produces a tension with no good answer inside a chat message:

- Write each row fully, and the surface is thousands of words. The reader stops reading.
- Compress each row, and the reader is approving a category label. They cannot tell what they are
  saying yes to.

Both were tried. Both failed, and the second failed worse, because a compressed table *looks*
reviewable. The reader can scan it, feel they have reviewed it, and approve something they never
actually read.

The tension is an artifact of the medium. In a linear chat message every line is equally loud, so
detail and brevity are genuinely zero-sum. On a page they are not: a one-line summary and the full
evidence can both exist, with the reader controlling which one they are looking at.

## What the board is

One HTML file, published as a private page, containing:

- A tally of the run, in candidate counts, where the buckets sum to the total evaluated.
- One section per routing destination (global rules, global memory, per project), each with its
  own approve/skip.
- One row per proposed write. Collapsed, a row is a number, a one-line claim, a confidence, and a
  route. Expanded, it carries the judgment call being handed over, the ground-truth incident with
  the user's own words, what the rule text would say, and the target path.
- A separate section for anything that is not a routing row: enforcement changes, boundary
  questions the system cannot resolve on its own.

The approval still comes back through chat, in one message. The page is for reading, not for
collecting input. Making it interactive would add a state channel that has to be read back, for no
gain.

## Design constraints that turned out to matter

### Let the design do the guiding, not the prose

If the page needs a sentence explaining how to use it, that sentence is a symptom. Do not tell the
reader to expand a row; put a triangle on it that rotates when open. Do not caption a group of
numbers to explain that two of them are different units; lay them out so the relationship is
visible. Attention is finite, and a reader who is confused is a design failure, not a reader
failure.

The concrete instance: four numbers were placed in one row, three of which summed to the fourth,
while a fifth quantity in a different unit sat among them. A paragraph was added underneath to
explain that the units differed. The paragraph was the wrong fix. Deleting it and rearranging the
row, with plus signs between the three addends, an equals sign before the total, and the
different-unit quantity demoted to a derived line under its parent, removed the need for any
explanation at all.

### Every status must state its disposition, not just its diagnosis

A bucket labeled "rule existed and was broken anyway" tells the reader what happened. It does not
tell them what will be done about it, which is the only thing they need in order to decide whether
to intervene. Each tally cell carries both: the state, and the arrow to what happens next. Colour
separates "you need to act on this" from "handled, no action needed", so the distinction does not
have to be read.

### Guide the reader to the decisions

On a long page the points that need an answer are otherwise indistinguishable from the points that
do not. Three devices, and no instructions:

- A sticky navigation strip listing every decision by number, each one a jump link. The reader
  always knows how many there are.
- A distinct visual treatment on the blocks that need an answer. If the rest of the page is
  hairline rules, a solid rail reads as different without introducing a new colour.
- One explicit question at each of those blocks, numbered to match the navigation.

### Two tabs, one stable URL

The published page keeps a single stable address that always shows the current run. A second tab
holds a ledger of past runs, read from the decision log rather than from recall, with a link to
each archived board. Old runs do not inline their detail into the current page, so the file does
not grow without bound.

### Generate the rows from data, not from markup

Hand-writing dozens of near-identical blocks invites omissions, and the omissions are silent. Bad
when the page is monolingual, worse when it is bilingual, where every block exists twice. Hold the
items in an array and render them, then assert the counts before publishing: rows rendered, numbers
contiguous, and for a bilingual page, the two language sets balanced.

### Verify the page in a real browser

Rendering functions can be dry-run in isolation, but that dry run stubs out the document, so none
of the wiring is exercised. Load the page in a real engine and check the behaviour: the toggle
actually toggles, the expand marker actually rotates, the filters actually filter, no errors are
raised.

One trap is worth naming because it produces a convincing false alarm. Loading the file over
`file://` without a charset declaration causes non-ASCII text to be decoded as latin-1 and render
as mojibake, which looks exactly like a real encoding bug in the page. The published page is fine,
because the publish step supplies the charset. Feed the HTML to the browser as a decoded string
instead, or serve it with a correct content type, and the false alarm disappears.

## Size rule for the chat fallback

Where a board is not being produced, cap any review surface at roughly **seven rows**, and batch
anything longer. Several rounds of approval on readable batches beat one round on a table nobody
can finish. The failure mode this prevents is subtle: faced with too many rows, the natural
response is to compress each row, which trades the one property, judgeability, that the surface
exists to provide.

## What not to do

- Do not add prose telling the reader how to operate the page.
- Do not compress a row below the point where the proposal can be judged. If it does not fit,
  there are too many rows on screen, not too many words in the row.
- Do not make the page collect the decision. The reader answers in one message; a form adds state
  that has to be read back out.
- Do not inline past runs. Link them.
- Do not claim the page works without having loaded it.
