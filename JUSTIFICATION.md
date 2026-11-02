# Instance Type Justification

Fill in your reasoning for each host below. This file is graded manually (10 of this assignment's 20 points) - the autograder checks that your Terraform code deploys and runs correctly (10 points), but only a human can evaluate whether your reasoning and cost analysis hold up.

Prices: us-west-2, Linux, shared tenancy, On-Demand, from the AWS Price List API (`aws pricing get-products`), cross-checked against the [EC2 On-Demand Pricing page](https://aws.amazon.com/ec2/pricing/on-demand/) and the [AWS Pricing Calculator](https://calculator.aws/). Monthly = hourly x 730 hours.

## Host A: Prompt Optimizer API

**Instance type chosen:** `t4g.micro` (Graviton / arm64, 2 vCPU, 1 GiB)

**Workload characteristics** (restate the relevant numbers from the assignment spec in your own words):
- About 250,000 requests/day (roughly 3 requests/second on average); business-hours traffic is about 10x the overnight rate.
- CPU is 8-12% at peak and under 2% overnight.
- About 150 MB of memory per process; latency budget under 100 ms.
- Early-stage product: cost matters and over-provisioning is an explicit concern.

**Why this instance family:**
- A low, bursty CPU load is what burstable (T-family) instances are for: the baseline is 10% per vCPU, credits build up overnight, and the daytime peak sits near the baseline with credits available for spikes.
- 1 GiB is plenty for a ~150 MB process.
- I chose Graviton (`t4g`) over `t3`: same specs and baseline, about 19% cheaper, and `app/server.py` uses only the Python standard library, so it runs on arm64 unchanged.

**Why not the alternatives** (address at least one instance family you did *not* choose, and why):
- **`c6i.large` (compute-optimized):** the workload uses about 10% of a small CPU, so paying for sustained compute is waste, at about 10x the cost.
- **`t3.micro`:** also workable, but costs more for the same capacity; it would only be preferable if a dependency were x86-only.

**Cost comparison:**

| | Your choice | Alternative considered |
|---|---|---|
| Instance type | `t4g.micro` | `t3.micro` |
| Hourly rate | $0.0084 | $0.0104 |
| Estimated monthly rate (24/7) | $6.13 | $7.59 |

(For scale, `c6i.large` is $0.0850/hour, $62.05/month.)

Does the cost difference change or confirm your reasoning above? It confirms it: `t4g.micro` saves about $1.46/month (19%) over `t3.micro` at no cost to the workload, and is about 10x cheaper than `c6i.large`, whose extra CPU would go unused. The smallest burstable instance is the right size here.

## Host B: Embedding Batch Regeneration Worker

**Instance type chosen:** `c6i.large` (Intel / x86_64, 2 vCPU, 4 GiB)

**Workload characteristics:**
- Runs once nightly at 2am for 45-60 continuous minutes, processing about 50,000 documents.
- CPU is sustained at 85-95% for the whole run (flat, not bursty).
- About 2 GB of working memory.
- Internal only (private subnet, no public IP).

**Why this instance family:**
- The bottleneck is sustained CPU, so compute-optimized (C-family) instances fit: full vCPU performance with no throttling.
- 4 GiB holds the 2 GB working set with headroom.
- The "i" in `c6i` means Intel, not Graviton, so this host uses the x86_64 (amd64) AMI.

**Why not T-family specifically** (this workload has a specific, well-defined failure mode with burstable instances - explain it):
- T-family performance depends on CPU credits. Taking `t3.medium` as the example, the baseline is 20% per vCPU (40% of the instance) and it earns 24 credits/hour (one credit = one vCPU-minute at 100%).
- Two vCPUs at about 90% burn about 108 credits/hour, a net drain of about 84 credits/hour.
- **Unlimited mode (the default for T3/T4g, which have no launch credits):** no throttling, but surplus credits are billed at about $0.05 per vCPU-hour on top of the instance price, so under sustained load the "cheap" instance stops being cheap.
- **Standard mode (must be set manually):** once credits run out the CPU is throttled to the 40% baseline, stretching a 1-hour job to roughly 3.5-4.5 hours.
- A full credit balance (maximum 576) would last about 7 hours at this burn rate, but that requires the instance to stay on all day to accrue credits, which conflicts with the start/stop schedule below, and leaves no headroom if the data grows.
- Source for the credit figures: [AWS burstable credits and baseline documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-credits-baseline-concepts.html).

**Cost comparison:**

Same as above - your chosen instance type vs. at least one rejected alternative.

| | Your choice | Alternative considered |
|---|---|---|
| Instance type | `c6i.large` | `t3.medium` |
| Hourly rate | $0.0850 | $0.0416 |
| Estimated monthly rate (24/7) | $62.05 | $30.37 |

`t3.medium` looks half the price, but under this load it incurs Unlimited-mode surcharges by default (or is throttled in Standard mode). I also considered `c6g.large` (Graviton, $0.0680/hour, $49.64/month, about 20% cheaper); I kept x86_64 because a nightly job is the most likely place to add native libraries later, which are the usual source of arm64 incompatibility.

**Realistic runtime consideration:** this worker only needs to run for its ~45-60 minute nightly window, not continuously. Estimate the monthly cost if it only ran during that window (roughly 1 hour/night) instead of 24/7, and briefly note what would be required to actually achieve that in practice (you do not need to implement this - just reason about it).
- 24/7: $0.0850 x 730 = **$62.05/month**.
- About 1 hour/night (30 hours/month): $0.0850 x 30 = **$2.55/month**, about 96% less.
- In practice: start the instance shortly before 2am and stop or terminate it when the job finishes, for example with EventBridge Scheduler or a Lambda function.
- The job is short and restartable, so it also suits **Spot** (up to about 90% off), provided it can resume after an interruption.
- Reserved Instances/Savings Plans do not fit, since the instance would be used only about 4% of the time.

## AI Tool Usage (if applicable)

I used an AI assistant (Claude Code).

**What I asked it:**
- Help read the assignment spec and the Module 6 slides and recommend an instance type for each host.
- To look up current On-Demand prices.
- To write `compute.tf`, `terraform.tfvars` and a first draft of this file.

**What it recommended:**
- API: `t4g.micro`; worker: `c6i.large`.

**What I specifically checked before accepting it:**
- **Bottleneck fit:** checked each recommendation against the numbers in the spec (API: 8-12% average CPU; worker: flat 85-95% CPU and 2 GB memory).
- **Burstable vs. sustained:** checked the T-family credit behavior against the Module 6 slides and the [AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-credits-baseline-concepts.html): `t3.medium` baseline 20% per vCPU, 24 credits/hour, maximum 576, and T3/T4g default to Unlimited mode. Then worked through the credit math myself.
- **Prices:** all from the AWS Price List API (us-west-2, Linux, On-Demand), and cross-checked on the [On-Demand pricing page](https://aws.amazon.com/ec2/pricing/on-demand/) and the [Pricing Calculator](https://calculator.aws/).
- **Specs:** confirmed with `aws ec2 describe-instance-types` that `t4g.micro` is arm64 with 1 GiB and `c6i.large` is x86_64 with 4 GiB, against the AWS docs for [T4g](https://docs.aws.amazon.com/ec2/latest/instancetypes/gp.html) and [C6i](https://docs.aws.amazon.com/ec2/latest/instancetypes/co.html).
- **Architecture/AMI match:** confirmed with `aws ec2 describe-images` that the arm64 SSM AMI is arm64 and the amd64 one is x86_64 (AMI lookup method per [Ubuntu's AWS documentation](https://ubuntu.com/aws/docs/aws-how-to/instances/find-ubuntu-images/)), and that `api` uses the arm64 AMI and `worker` the amd64 AMI.
- **Plan:** `terraform plan` showed the expected `instance_type` and public/private placement for each host.
