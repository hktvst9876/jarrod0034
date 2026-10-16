# Steady brief-to-starter audit notes

Status: **planning evidence; no source files changed**

## 1. Continuity finding

The interrupted session completed research and gap analysis but did not write its promised proposal or README. It did not implement or test any Swift code.

The two available `steady-starter` folders are byte-for-byte identical. Each contains only ten documentation/seed files. Neither contains an Xcode project, Swift package, Swift source, Git metadata, README, or proposal.

## 2. Requirements trace summary

The earlier detailed trace split the newer brief into 167 atomic requirements:

- 68 covered by the starter;
- 77 partially covered;
- 12 missing; and
- 10 directly conflicting.

Strong existing foundations include the pure-Swift core, deterministic daily-priority rules, Plan A/alternative concept, confirmation-bound calendar writes, no-guilt tone, local notification limit, manual fallbacks, low-data mode, and much of the safety policy.

## 3. Conflicts requiring explicit replacement decisions

### Phase order

The starter uses M0–M10. The newer brief requires seven phases and places Daily Foundations and the advisor before live food and Watch. The proposal adopts the newer order while retaining the starter's internal work as substeps.

### Advisor and networking

Starter decision D4 forbids cloud AI, API keys, backends, and networking beyond MapKit. The newer brief asks for one advisory agent, optional cloud consent, live menu research, freshness, and citations.

Recommended resolution: preserve an offline `TemplateAdvisor`, allow availability-gated on-device Foundation Models, and leave cloud infrastructure unimplemented until separately approved. Do not silently weaken D4; add a dated replacement decision.

### Food evidence

The brief says never to invent menus, prices, opening times, or nutrition. Existing `foods.json` contains rough, mostly uncited nutrition and “typical” prices. Those values can be reference material but cannot appear as verified results.

Recommended resolution: rebuild the model around sources, check times, uncertainty reasons, and explicit unavailable states. Use cited SG FoodID records or remembered user corrections.

### Money features

The starter makes price prominent and includes weekly food spend and estimated money saved. The newer product direction says money tracking must not be central.

Recommended resolution: retain an optional per-meal price preference because affordability affects feasibility, but remove aggregate spending and money-saved scoring from release 1.

### Craving system

The starter's dedicated Urge flow, treat quota, and money-saved estimate are broader than the newer brief and can create accidental moral pressure.

Recommended resolution: treat late hunger, delivery preference, sweet drinks, and phone use as ordinary user-selected barriers. Do not ship a treat quota or savings score in release 1.

## 4. Important missing requirements

The starter does not yet specify or model:

- neutral bedtime actions: rest, adjust tomorrow, or do nothing;
- nutrition uncertainty reasons;
- source URLs and check times for live food claims;
- an expiring live-result cache;
- the advisor's coarse wellness-context tool;
- candidate allowlisting and live-citation validation;
- a no-inference guard for allergies, injuries, diagnoses, and emotions;
- clearing advisor history without deleting wellness records;
- planned sleep-window handling for notifications;
- time-to-choose and user-reported helpfulness metrics; or
- a root README with setup and current status.

These are included in the proposal and data model.

## 5. Seed alternative defects to fix before Phase 2

The current `alternatives.json` contains 62 alternatives across eight plan types, but it does not fully meet the newer contract:

- twelve plan/barrier lists contain only one option;
- several sets reuse an effort level rather than presenting meaningfully different effort;
- one craving ladder contains four options although the limit is three;
- multiple options say they give up “Nothing,” which does not identify a real tradeoff; and
- rest, wait, treat, and reschedule behaviors are mixed into option lists inconsistently.

Before use in production, every set needs two or three primary options, honest benefit/tradeoff text, explicit preserved and lost outcome parts, and separate defer/rest actions.

## 6. Seed food safety defects to fix before Phase 5

The current `foods.json` contains 38 dishes and 14 grocery items. Key problems include:

- ingredient lists marked `likely` can be incomplete;
- an empty `contains` list can accidentally look safe for every allergy;
- common preparation variants may introduce peanut, soy, gluten, egg, dairy, sesame, fish, or shellfish without appearing in the list;
- nutrition ranges are rough estimates without per-result references; and
- most prices are typical values rather than current sourced facts.

The production filter must distinguish verified completeness from unknown ingredients. Unknown is not safe. A known conflict is excluded, while an incomplete list is confirmation-needed and cannot be the primary recommendation.

## 7. Starter decisions to preserve

Keep these principles:

- native SwiftUI and Apple frameworks;
- iOS 18/watchOS 11 baseline;
- pure, Foundation-only `SteadyCore`;
- injected time and Singapore calendar;
- real and sample protocol-backed services;
- on-device personal records;
- no hand-editing `project.pbxproj`;
- every calendar write confirmed and limited to Steady-owned events;
- low-data mode across phone, Watch, notifications, advisor packets, and exports; and
- no guilt or failure wording.

## 8. Environment limitation

The current host is Windows and has no Swift compiler, Xcode, simulator, or WSL installation. It cannot build an iOS or watchOS target. A Mac with Xcode is therefore part of the definition of done, not an optional follow-up.

The safe next action is to approve the proposal, create the required Xcode project/Watch target on a Mac, and then implement Phase 1 against that real scaffold.
