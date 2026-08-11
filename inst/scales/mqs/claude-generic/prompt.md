RUN_VERSION: v019
MODEL: shared provider-neutral MQS prompt
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
  - This item is scored by counting VALID CONTROL CATEGORIES, not by judging whether the study is generally well controlled.
  - First exclude non-valid evidence. Do NOT count: statistical analyses, covariate adjustment, baseline equivalence checks, demographic comparisons, measurement standardization, coder training, inter-rater reliability, psychometric reliability, routine treatment manuals, or ordinary descriptions of outcome assessment.
  - Then group the remaining valid evidence into the categories below. Count each category only once, even if it appears several times.

  Valid control categories:
  [A] Random allocation or allocation control: random assignment, random allocation, allocation sequence, concealed allocation, blocking, stratification, minimization, or any equivalent allocation procedure. Count all of these together as ONE category.
  [B] Control/comparison condition: waitlist, usual care, treatment as usual, no-treatment control, placebo, sham, attention control, alternative active treatment, or another explicit comparison arm. Count all comparison-arm variants together as ONE category.
  [C] Blinding or masking: blinded assessors, masked coders, blinded participants, blinded therapists/trainers, or blind rating. Count all blinding/masking together as ONE category.
  [D] Matching, pairing, or counterbalancing: matching participants/groups, yoked/pairing procedures, counterbalanced order, or equivalent procedural balancing.
  [E] Other explicit procedural control: any clearly named design/procedural control intended to reduce confounding and not already counted above.

  Scoring rule:
  - Score 0.0 if ZERO valid categories are present after exclusions.
  - Score 0.5 if EXACTLY ONE valid category is present.
  - Score 1.0 if TWO OR MORE valid categories are present.
  - Do not skip the 0.5 score. If there is one valid category, the score MUST be 0.5, not 0.0 or 1.0.
  - If unsure whether a second category is truly distinct, do not count it; score based on the confirmed number of valid categories.

  Before choosing the score, silently list the valid categories found and count them. The final answer must still follow the mandatory output format.
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


--- STRICT JSON OUTPUT ---
Return one valid JSON object only. Do not use Markdown fences or add any text outside the JSON object.
Use the exact MQS JSON schema documented in the matching metadata.json: items 1 through 10, each with decision, evidence, and reason.
Use only 0.0, 0.5, 1.0, or 9.0 where the rubric allows not applicable.

