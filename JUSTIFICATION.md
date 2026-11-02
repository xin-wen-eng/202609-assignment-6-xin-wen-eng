# Instance Type Justification

Fill in your reasoning for each host below. This file is graded manually (10 of this assignment's 20 points) - the autograder checks that your Terraform code deploys and runs correctly (10 points), but only a human can evaluate whether your reasoning and cost analysis hold up.

## Host A: Prompt Optimizer API

**Instance type chosen:**

**Workload characteristics** (restate the relevant numbers from the assignment spec in your own words):

**Why this instance family:**

**Why not the alternatives** (address at least one instance family you did *not* choose, and why):

**Cost comparison:**

State the On-Demand hourly and estimated monthly rate (us-west-2) for your chosen instance type, and for at least one alternative instance type you considered but rejected. Use the [AWS Pricing Calculator](https://calculator.aws/), the [EC2 On-Demand Pricing page](https://aws.amazon.com/ec2/pricing/on-demand/), or an AI assistant (see Module 6) to find these figures.

| | Your choice | Alternative considered |
|---|---|---|
| Instance type | | |
| Hourly rate | | |
| Estimated monthly rate (24/7) | | |

Does the cost difference change or confirm your reasoning above? Explain briefly.

## Host B: Embedding Batch Regeneration Worker

**Instance type chosen:**

**Workload characteristics:**

**Why this instance family:**

**Why not T-family specifically** (this workload has a specific, well-defined failure mode with burstable instances - explain it):

**Cost comparison:**

Same as above - your chosen instance type vs. at least one rejected alternative.

| | Your choice | Alternative considered |
|---|---|---|
| Instance type | | |
| Hourly rate | | |
| Estimated monthly rate (24/7) | | |

**Realistic runtime consideration:** this worker only needs to run for its ~45-60 minute nightly window, not continuously. Estimate the monthly cost if it only ran during that window (roughly 1 hour/night) instead of 24/7, and briefly note what would be required to actually achieve that in practice (you do not need to implement this - just reason about it).

## AI Tool Usage (if applicable)

If you used an AI assistant to help choose an instance type or estimate costs, briefly describe:
- What you asked it
- What it recommended or estimated
- What you specifically checked or verified before accepting (or rejecting) that recommendation

If you did not use an AI assistant for this assignment, you can state that here instead.
