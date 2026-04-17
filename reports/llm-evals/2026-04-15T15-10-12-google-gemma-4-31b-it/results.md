# LLM Eval Results

- date: `2026-04-15`
- model: `google/gemma-4-31B-it`
- endpoint: `http://127.0.0.1:8000/v1`
- prompt pack: `general-agent-v1`

## Tasks

| Task | Latency | Finish | Prompt | Completion | Total |
| --- | ---: | --- | ---: | ---: | ---: |
| `email_triage` | `36.13`s | `stop` | `304` | `231` | `535` |
| `tool_choice` | `2.666`s | `tool_calls` | `201` | `16` | `217` |
| `english_rewrite` | `10.242`s | `stop` | `130` | `67` | `197` |
| `relevance_judgment` | `28.748`s | `stop` | `274` | `189` | `463` |
| `messy_context_decision` | `14.824`s | `stop` | `119` | `97` | `216` |
| `meeting_prep` | `15.451`s | `stop` | `159` | `101` | `260` |
| `structured_following` | `18.759`s | `stop` | `99` | `123` | `222` |
| `ambiguity_handling` | `6.661`s | `stop` | `74` | `43` | `117` |

## `email_triage`

### Content

```
```json
{
  "urgent_now": [
    4,
    1,
    7
  ],
  "today_not_urgent": [
    8,
    5
  ],
  "low_priority": [
    2,
    3,
    6
  ],
  "delegate": [
    {
      "id": 8,
      "delegate_to": "Engineering Manager",
      "why": "Technical implementation detail regarding feature flags"
    },
    {
      "id": 2,
      "delegate_to": "HR/Recruiting Coordinator",
      "why": "Scheduling logistics for candidate interviews"
    }
  ],
  "draft_reply": {
    "id": 4,
    "subject": "Re: Webhook failure in production",
    "body": "I am aware of the webhook failures and have alerted the engineering team. We are investigating the root cause now and I will provide a firm ETA within the hour."
  }
}
```
```

## `tool_choice`

### Tool calls

```json
[
  {
    "id": "chatcmpl-tool-997f5d282e4a9ca9",
    "type": "function",
    "function": {
      "name": "search_email",
      "arguments": "{\"query\": \"board prep\"}"
    }
  }
]
```

### Raw response

```json
{
  "id": "chatcmpl-8d879ee056f9cca8",
  "object": "chat.completion",
  "created": 1776258648,
  "model": "google/gemma-4-31B-it",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": null,
        "refusal": null,
        "annotations": null,
        "audio": null,
        "function_call": null,
        "tool_calls": [
          {
            "id": "chatcmpl-tool-997f5d282e4a9ca9",
            "type": "function",
            "function": {
              "name": "search_email",
              "arguments": "{\"query\": \"board prep\"}"
            }
          }
        ],
        "reasoning": null
      },
      "logprobs": null,
      "finish_reason": "tool_calls",
      "stop_reason": 50,
      "token_ids": null
    }
  ],
  "service_tier": null,
  "system_fingerprint": null,
  "usage": {
    "prompt_tokens": 201,
    "total_tokens": 217,
    "completion_tokens": 16,
    "prompt_tokens_details": null
  },
  "prompt_logprobs": null,
  "prompt_token_ids": null,
  "kv_transfer_params": null
}
```

## `english_rewrite`

### Content

```
Hi team, 

Just a reminder that the current draft isn't ready for the client. There is still too much ambiguity around the pricing, and sending it as-is would create more confusion than clarity. 

Please tighten up the wording and send me one clean, final version by tomorrow morning. 

Thanks!
```

## `relevance_judgment`

### Content

```
```json
{
  "read_now": [
    "E",
    "C",
    "G",
    "A"
  ],
  "skim_if_time": [
    "D"
  ],
  "ignore_for_this_meeting": [
    "B",
    "F",
    "H"
  ],
  "rationale": "Priority is given to direct board requests (E), critical financial wins (G), and high-stakes risks (C, A). A board member's specific question is the top priority. The churn risk of the largest account is a critical board-level update. Improving gross margins is a key performance win. The security issue is a necessary disclosure. PRD is secondary. Admin tasks, junior hiring, and raw data dumps are irrelevant for a strategic board preparation call."
}
```
```

## `messy_context_decision`

### Content

```
* **Decision:** Delay the launch to next Tuesday.
* **Reasoning:** Pushing a billing change during a support spike risks a catastrophic failure in customer experience and churn of the largest enterprise account.
* **Risk:** Finance may miss the quarterly window if the delay pushes the effective date into the next period.
* **Next Step:** Product team to coordinate with the Account Manager to provide the enterprise customer a preview of the new format for sign-off by Friday.
```

## `meeting_prep`

### Content

```
* **Read First:** Customer incident summary (critical for the churn call).
* **Decide Beforehand:** The specific "win-back" offer or concession for the escalating account.
* **Ask Recruiter:** Which of the two candidates requires visa sponsorship and the associated timeline/cost.
* **Confirm for Board:** Final status of the Q2 metrics deck and key talking points.
* **Churn Call Opening:** Acknowledge the failure immediately and express a commitment to resolution.
```

## `structured_following`

### Content

```
```json
{
  "recommendation": "move to Linear + Google Docs",
  "why": "This separates structured project tracking from unstructured documentation, providing superior speed and specialized tooling for software development while maintaining universal accessibility for docs.",
  "tradeoffs": [
    "Increased context switching between two different platforms",
    "Loss of a single 'source of truth' for all company knowledge",
    "Additional subscription management and billing overhead"
  ],
  "who_should_own_the_decision": "CTO or Head of Product"
}
```
```

## `ambiguity_handling`

### Content

```
To give you the right wording, I need to know: **What is Sam blocking, and what is the specific "thing" (approval, data, a signature, etc.) you need from him?**
```
