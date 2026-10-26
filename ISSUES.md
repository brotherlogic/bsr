# BSR - GitHub Issue Processing Workflow

This document serves as the entry point and index for Seraphine's issue-processing workflows. It outlines the general rules and lists the specific workflow files for each stage in the issue lifecycle.

**Note:** Always use **native GitHub sub-issues** when defining parent-child issue relationships to ensure proper tracking within GitHub.

---

## 🚫 Critical General Rules
1. **Scope Adherence**: The agent should only address the labeled issue, and it must stop once the issue is unlabeled.
2. **Termination Rule**: **The agent should not proceed to the next label.** Once you have removed a label from the bug (or a PR is merged), you should stop execution immediately. Do not trigger or begin processing the next stage or label in the same run.
3. **Issue Assignment**: **Whenever a new issue (or sub-issue) is created, it MUST be assigned to `brotherlogic-automation`.**
4. **Label Removal Ordering**: **Always remove the `seraphine-*` label as the very last step of the workflow.** Because removing the label signals phase completion and may immediately terminate the container/session, all comments, sub-issues, and artifacts must be created *before* the `seraphine-*` label is removed.

---

## 🏷️ Workflow Stages & Labels

When an issue is labeled, refer to the corresponding workflow document under `.agents/workflows/` for detailed step-by-step instructions:

1. **Problem Decomposition**
   - **Label**: `seraphine-decompose`
   - **Workflow Guideline**: [seraphine-decompose.md](file:///workspaces/bsr/.agents/workflows/seraphine-decompose.md)

2. **Deep Research**
   - **Label**: `seraphine-needs-deep-research`
   - **Workflow Guideline**: [seraphine-needs-deep-research.md](file:///workspaces/bsr/.agents/workflows/seraphine-needs-deep-research.md)

3. **Requirements gathering**
   - **Label**: `seraphine-needs-requirements` (or variant `seraphine-need-requirements`)
   - **Workflow Guideline**: [seraphine-needs-requirements.md](file:///workspaces/bsr/.agents/workflows/seraphine-needs-requirements.md)

4. **Technical implementation plan formulation**
   - **Label**: `seraphine-needs-implementation-plan`
   - **Workflow Guideline**: [seraphine-needs-implementation-plan.md](file:///workspaces/bsr/.agents/workflows/seraphine-needs-implementation-plan.md)

5. **Issue breakdown**
   - **Label**: `seraphine-break-down-issue`
   - **Workflow Guideline**: [seraphine-break-down-issue.md](file:///workspaces/bsr/.agents/workflows/seraphine-break-down-issue.md)

6. **Component implementation**
   - **Label**: `seraphine-ready-to-implement`
   - **Workflow Guideline**: [seraphine-ready-to-implement.md](file:///workspaces/bsr/.agents/workflows/seraphine-ready-to-implement.md)

7. **Bug triage and resolution**
   - **Label**: `seraphine-bug`
   - **Workflow Guideline**: [seraphine-bug.md](file:///workspaces/bsr/.agents/workflows/seraphine-bug.md)

8. **Bug analysis**
   - **Label**: `seraphine-bug-analysis`
   - **Workflow Guideline**: [seraphine-bug-analysis.md](file:///workspaces/bsr/.agents/workflows/seraphine-bug-analysis.md)

---

## 🛠️ Summary of Expected Label State Transitions

| Phase | Parent Issue Label(s) | Sub-Issue Title & Label(s) |
| :--- | :--- | :--- |
| **Problem Decomposition** | `seraphine-decompose` | Child sub-issues created and labeled with `seraphine-needs-requirements` (or `seraphine-decompose` for complex sub-modules), then `seraphine-decompose` removed as the final step. |
| **Deep Research** | `seraphine-needs-deep-research` | *None (Not yet created)* |
| **Deep Research Complete** | `seraphine-needs-deep-research` (Removed last) | Sub-issue `[Requirements] <Title>` created and labeled with `seraphine-needs-requirements`, then `seraphine-needs-deep-research` removed as the final step. |
| **Requirements Gathering** | `seraphine-needs-requirements` | *None (Not yet created)* |
| **Requirements Approved** | *(Label Removed last)* | Sub-issue `[Implementation Plan] <Title>` created and labeled with `seraphine-needs-implementation-plan`, then `seraphine-needs-requirements` removed as the final step. |
| **Implementation Plan Drafting** | *None* | `[Implementation Plan] <Title>` labeled with `seraphine-needs-implementation-plan` |
| **Implementation Plan Approved** | *None* | **Breakdown Sub-Issue:** `[Breakdown] <Title>` created and labeled with `seraphine-break-down-issue`.<br>**Implementation Plan:** Label removed as the final step (remains Open). |
| **Issue Breakdown** | *None* | **Child Sub-Issues:** `[Sub-Issue] <Action>` created and labeled with `seraphine-ready-to-implement`.<br>**Breakdown Issue:** `seraphine-break-down-issue` removed as the final step (remains Open). |
| **Implementation** | *None* | **Breakdown Issue:** Closed when all child sub-issues are closed (cascading to close Implementation Plan and Parent issues).<br>**Child Sub-Issues:** Labeled with `seraphine-ready-to-implement`. Closed programmatically via PR submission. |
| **Bug Triage (Simple)** | `seraphine-bug` | *None (Direct fix implemented and PR submitted)* |
| **Bug Triage (Complex/Failed)** | `seraphine-bug` (Removed last) | Sub-issue created and labeled with `seraphine-needs-requirements` to initiate requirements gathering, then `seraphine-bug` removed as the final step. |
| **Bug Analysis** | `seraphine-bug-analysis` | *None (Analysis posted to issue; label retained for follow-up conversation)* |
