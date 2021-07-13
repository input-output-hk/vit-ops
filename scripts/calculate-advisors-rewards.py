"""Usage: calculate-advisors-rewards.py --seed=STRING --proposals=FILE --non-eligible-advisors=FILE --advisors=FILE --total-incentive=INT [--output=FILE]

Options:
    --seed <string>  seed used for random selection of reviews
    --proposals <file> file containing the reviews for each proposal
    --non-eligible-advisors <file> file containing non eligible advisors
    --advisors <file> file containing info for each advisor
    --total-incentive <int> the amount of funding (in $) allocated to community advisors
    --output <file> [ default: output.csv ]
"""

from docopt import docopt
import random
import pandas
import math
from collections import Counter

NUM_WINNERS_PER_PROPOSAL = 3

arguments = docopt(__doc__)
# 'ffil' fill empty columns using last valid value
# (merged rows in spreadsheet are serialized with only the first row retaining the value)
proposals = pandas.read_csv(arguments["--proposals"]).fillna(method="ffill")
non_eligible_advisors = set(
    pandas.read_csv(arguments["--non-eligible-advisors"]).iloc[:, 0].values.tolist()
)
# Extract just email and wallet address (there does not seem to be a stable column name yet)
advisors = {
    k: v for k, v in pandas.read_csv(arguments["--advisors"]).iloc[:, 1:3].values
}

seed = arguments["--seed"]
print(f"Using seed: {seed}")
rng = random.Random()
# Explicitly set version so we get compatible results between Python versions
rng.seed(seed, version=2)

winners = []
for proposal_name, reviews in proposals.groupby(proposals.columns[0]):
    # Advisor email in column F
    assessors = set(pandas.unique(reviews.iloc[:, 5].dropna())) - non_eligible_advisors
    proposal_winners = (
        # Sort to ensure consistent set iteration
        rng.sample(list(sorted(assessors)), NUM_WINNERS_PER_PROPOSAL)
        if len(assessors) >= NUM_WINNERS_PER_PROPOSAL
        else assessors
    )
    winners.extend(proposal_winners)

total_incentive = int(arguments["--total-incentive"])
funding_per_winner = total_incentive / len(winners)

rows = []
total = 0
winner_counter = Counter(winners)
for winner, wins_count in winner_counter.most_common():
    try:
        address = advisors[winner]
    except:
        address = "Not available"
    rows.append([winner, wins_count * funding_per_winner, address])
    total += wins_count * funding_per_winner

# Ensure we do not distribute more rewards than are available
assert math.isclose(total, total_incentive, abs_tol=1e-3)

output_file = (
    arguments["--output"] if arguments["--output"] is not None else "output.csv"
)
pandas.DataFrame(rows, columns=["Email", "Funding ($)", "ADA payment address"]).to_csv(
    output_file
)
print(f"Output written to {output_file}")
