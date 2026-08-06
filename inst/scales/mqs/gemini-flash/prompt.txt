RUN_VERSION: v019
MODEL: gemini-2.5-flash
CALLS_PER_ARTICLE: 1

--- MQS SCALE DESCRIPTION ---

--- METHODOLOGICAL QUALITY SCALE (MQS) DEFINITION & SCORING RUBRIC ---

You are a strict, highly literal Senior Scientific Auditor. Evaluate MQS exactly as written below.
GLOBAL RULE: Use explicit information from text, tables, figures, captions, and flow diagrams. Do not invent evidence. If counts, timelines, or eligibility rules are reported, you may calculate or classify from them. If evidence is absent or ambiguous, score lower.

* ITEM 1: Inclusion and exclusion criteria
  - Instruction: Look in Participants, Sample, Recruitment, Procedure, Eligibility, and Methods sections.
  - LLM Heuristic: Count explicit eligibility, diagnostic, referral, professional-role, setting, recruitment, inclusion, and exclusion rules as criteria. Do not require the exact words "inclusion criteria".
  - Score 1.0: Yes (replicable). Explicit selection criteria exist and no exceptions or partial application are reported.
  - Score 0.5: Intermediate. Selection criteria are partial/vague, or application to all candidates is unclear.
  - Score 0.0: No. No explicit selection criteria, or applied with exceptions.

* ITEM 2: Total Attrition (Loss of participants)
  - Instruction: Check CONSORT, tables, and Results. Loss is AFTER assignment/enrollment/baseline.
  - Academic Sensitivity: Score 1.0 if participant flow is clear and numbers are consistent, even when reasons are generic or reported separately.
  - LLM Heuristic: Treat explicit N counts across time points or a completed flow table as strong evidence. Look for "dropouts", "lost to follow-up", "withdrew", "usable sample", "returned sample", "completed".
  - Score 1.0: Specified. ZERO attrition is explicit or calculable, OR lost/completer numbers are calculable across time points and the participant flow is clear and numerically consistent.
  - Score 0.5: Intermediate. Some numbers or reasons are reported, but total attrition remains only partially specified.
  - Score 0.0: Unspecified. Neither numbers nor reasons are available.

* ITEM 3: Attrition between groups
  - Instruction: Evaluate dropout differences between arms.
  - Academic Sensitivity: Score 1.0 if group flow is clear and numerically consistent, even with generic reasons.
  - LLM Heuristic: Look at N per group at study end and tables that list group-by-time counts.
  - Score 9.0: Not applicable. Score 9.0 ONLY if the study has a single-group design or no cross-group comparison.
  - Score 1.0: Specified. ZERO attrition in all groups is explicit or calculable, OR lost/completer numbers are calculable for each group with clear and consistent group flow.
  - Score 0.5: Intermediate. Group-level counts or reasons are reported, but losses cannot be fully calculated for every arm.
  - Score 0.0: Unspecified. Missing numbers and missing reasons per group.

* ITEM 4: Statistical methods for imputing missing data
  - Instruction: Look in "Data Analysis" or "Statistical Analysis".
  - Academic Sensitivity: Count HLM, FIML, ML, maximum likelihood, MI, expectation maximization, or similar inclusive missing-data methods when they are used to handle missing values.
  - LLM Heuristic: Listwise/pairwise deletion or completers-only analysis means 0.0. Look for MI, FIML, ML, maximum likelihood, EM/expectation maximization, HLM, multilevel modeling, LOCF, or an explicit missing-values analysis.
  - Do not use 9.0 for this item. If there are no missing outcome data to handle, score 1.0.
  - Score 1.0: Low risk. No missing outcome data need handling, OR an inclusive missing-data method is named and used, including EM/expectation maximization, FIML, ML, maximum likelihood, HLM/multilevel models with incomplete cases, LOCF, or MI.
  - Score 0.5: Medium risk. A missing-data method or missing-values analysis is mentioned, but the rationale or implementation details are incomplete.
  - Score 0.0: High risk. Unclear attrition, or analysis was carried out without imputing missing data.

* ITEM 5: Methodology or design
  - Instruction: Look in "Methods" or "Design".
  - Academic Intention Rule: If the study is described/analyzed as an RCT, score 1.0 even with minor randomization failures.
  - LLM Heuristic: "Random sample" is not random assignment. Look for "randomly allocated", "random assignment", "allocation sequence", "computer-generated randomization".
  - Score 1.0: Experimental / Randomized. Explicit statement that units were randomly assigned to conditions.
  - Score 0.5: Quasi-experimental. Two groups without randomized assignment (e.g., non-equivalent control) OR one group with three or more measurement occasions.
  - Score 0.0: Pre-experimental / Observational. One group with max two measurement occasions, or two groups with only one measure.

* ITEM 6: Follow-up period
  - Instruction: Time elapsed after the main intervention/training/workshop ends until later outcome measurement.
  - For training/workshop trials, count follow-up from core training completion; ignore later feedback/reminders/supervision unless explicitly part of the intervention. Do not count in-intervention measurements.
  - Score 1.0: More than 6 months.
  - Score 0.5: Between 2 and 6 months (both included).
  - Score 0.0: No follow-up, unclear follow-up, in-intervention assessment only, or less than 2 months.
* ITEM 7: Measurement occasions
  - Instruction: Timeline of dependent-variable data collection.
  - Score 1.0: Pre-test plus post-intervention measurement and a later follow-up after the intervention/training ended.
  - Score 0.5: Pre-test plus only one post-baseline outcome occasion, even if delayed; or unclear distinction between post-test and follow-up.
  - Score 0.0: Post-intervention only.

* ITEM 8: Control techniques
  - Instruction: Look for active procedural controls that neutralize confounders during intervention delivery, not analysis methods or measurement quality.
  - Conservative exclusions:
    1. EXCLUDE randomization/balancing forms: random assignment, urn randomization, stratified randomization, blocking/minimization, balancing on baseline variables.
    2. EXCLUDE baseline equivalence checks, demographics comparisons, and "no significant differences at baseline".
    3. EXCLUDE routine statistical analyses or ordinary covariate adjustments, including ANOVA, MANOVA, MANCOVA, ANCOVA, t-tests, regression, HLM, and baseline covariates.
    4. EXCLUDE standardized measurement/assessment procedures, standardized clients/actors, coder training, coding reliability, and instrument standardization.
    5. EXCLUDE ordinary trial-arm labels or allocation structures such as waiting list control, usual care, or placebo arm when they are only part of the study design.
  - Valid categories:
    [Category A]: Blinding or masking procedure. Count blinding/masking as one category even if it covers participants, trainers, assessors, or coders.
    [Category B]: Matching/pairing or counterbalancing applied to intervention delivery or order.
    [Category C]: Placebo/sham/attention-control procedures explicitly used to control confounding during the intervention itself. Do not count ordinary control-group labels, self-training arms, waiting lists, or usual care unless the paper explicitly frames them as attention-control procedures.
    [Category D]: Other explicitly named procedural controls separate from randomization, measurement standardization, and ordinary arm assignment.
  - Score 1.0: At least two valid categories are present.
  - Score 0.5: Exactly one valid category is present.
  - Score 0.0: Zero valid categories present after applying exclusions.
* ITEM 9: Standardization of the dependent variables
  - Instruction: Look in the "Measures" or "Instruments" section.
  - Academic Sensitivity: One psychometric property (alpha, Omega, ICC, or validity evidence) from the study's OWN sample is enough for 1.0.
  - LLM Heuristic: A past validation paper does not count. The text must report alpha, Omega, ICC, or validity from the CURRENT sample.
  - Score 1.0: High. At least ONE solid psychometric property is reported from their OWN sample.
  - Score 0.5: Medium. Psychometric properties are reported ONLY from past literature, OR the property is mentioned but the source/sample is ambiguous.
  - Score 0.0: Low. Ad hoc tools with no psychometric properties reported anywhere.

* ITEM 10: Construct definition of outcome
  - Instruction: Look in the "Introduction" (conceptual) and "Measures" (empirical).
  - Academic Sensitivity: Search the Introduction, theoretical framework, background, or literature review for conceptual definitions.
  - LLM Heuristic: Conceptual = theory behind the variable. Empirical = how it is measured in this paper.
  - Score 1.0: Defined BOTH conceptually AND empirically; empirical definition can be the named operational measure/instrument used for the dependent variable.
  - Score 0.5: Defined conceptually OR empirically, but not both.
  - Score 0.0: No definition provided.


--- SINGLE CALL INSTRUCTIONS ---
Evaluate ALL MQS Items 1 through 10 in one pass using the rubric above.
Return exactly one line per item, in numeric order, with this format:
* Item [X]: [Score] | Justification: [Evidence]
Use only 0.0, 0.5, 1.0, or 9.0 where the rubric allows not applicable.
Do not add summaries, markdown tables, headings, or conversational text.

