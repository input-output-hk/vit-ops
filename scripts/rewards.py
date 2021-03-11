from typing import Dict, Optional, List, Union, Tuple, Set

import itertools
from collections import namedtuple

import pydantic
import httpx

# VIT servicing station models

ADA = '₳'
FUNDED = "FUNDED"
NOT_FUNDED = "NOT_FUNDED"
YES = "YES"
NO = "NO"
OVER_BUDGET = "Not Funded - Over Budget"
APPROVAL_THRESHOLD = "Not Funded - Approval Threshold"
LOVELACE_FACTOR = 1000000


class Proposal(pydantic.BaseModel):
    internal_id: int
    proposal_id: str
    proposal_title: str
    proposal_funds: int
    proposal_url: str
    chain_proposal_id: str
    chain_proposal_index: int
    chain_vote_options: Dict[str, int]
    fund_id: int
    challenge_id: int
    challenge_type: str


# Jormungandr models

class Options(pydantic.BaseModel):
    start: int
    end: int


class TallyResult(pydantic.BaseModel):
    results: List[int]
    options: Options


class ProposalStatus(pydantic.BaseModel):
    index: int
    proposal_id: str
    options: Options
    tally: Optional[TallyResult]
    votes_cast: int


class VoteplanStatus(pydantic.BaseModel):
    id: str
    payload: str
    proposals: List[ProposalStatus]


# API loaders

async def get_proposals(vit_servicing_station_url: str) -> List[Proposal]:
    async with httpx.AsyncClient() as client:
        proposals_result = await client.get(f"{vit_servicing_station_url}/api/v0/proposals")
        assert proposals_result.status_code == 200
        return [Proposal(**proposal_data) for proposal_data in proposals_result.json()]


async def get_active_voteplans(vit_servicing_station_url: str) -> List[VoteplanStatus]:
    async with httpx.AsyncClient() as client:
        proposals_result = await client.get(f"{vit_servicing_station_url}/api/v0/vote/active/plans")
        assert proposals_result.status_code == 200
        return [VoteplanStatus(**proposal_data) for proposal_data in proposals_result.json()]


async def get_proposals_and_voteplans(vit_servicing_station_url: str) \
        -> Tuple[Dict[str, Proposal], Dict[str, ProposalStatus]]:
    proposals_task = asyncio.create_task(get_proposals(vit_servicing_station_url))
    voteplans_task = asyncio.create_task(get_active_voteplans(vit_servicing_station_url))

    proposals = {proposal.proposal_id: proposal for proposal in await proposals_task}
    voteplans_proposals = {
        proposal.proposal_id: proposal
        for proposal in itertools.chain.from_iterable(voteplan.proposals for voteplan in await voteplans_task)
    }
    return proposals, voteplans_proposals


# Checkers

def sanity_check_data(proposals: Dict[str, Proposal], voteplan_proposals: Dict[str, ProposalStatus]) -> bool:
    if set(proposals.keys()) != set(voteplan_proposals.keys()):
        raise Exception("Extra proposals found, voteplan proposals do not match servicing station proposals")
    if any(proposal.tally is None for proposal in voteplan_proposals.values()):
        raise Exception(f"Some proposal do not have a valid tally available")
    return True


# Analyse and compute needed data

def extract_yes_no_votes(proposal: Proposal, voteplan_proposal: ProposalStatus):
    yes_index = proposal.chain_vote_options["yes"]
    no_index = proposal.chain_vote_options["no"]
    # we check before if tally is available, so it should be safe to direct access the data
    yes_result = voteplan_proposal.tally.results[yes_index]  # type: ignore
    no_result = voteplan_proposal.tally.results[no_index]  # type: ignore
    return yes_result, no_result


def calc_approval_threshold(
        proposal: Proposal,
        voteplan_proposal: ProposalStatus,
        threshold: float
) -> Tuple[int, bool]:
    yes_result, no_result = extract_yes_no_votes(proposal, voteplan_proposal)
    diff = yes_result - no_result
    success = diff >= (no_result*threshold)
    return diff, success


def calc_vote_difference_and_threshold_success(
        proposals: Dict[str, Proposal],
        voteplan_proposals: Dict[str, ProposalStatus],
        threshold: float
) -> Dict[str, Tuple[int, bool]]:
    full_ids = set(proposals.keys())
    result = {
        proposal_id: calc_approval_threshold(proposals[proposal_id], voteplan_proposals[proposal_id], threshold)
        for proposal_id in full_ids
    }
    return result


Result = namedtuple(
    "Result",
    (
        "proposal",
        "yes",
        "no",
        "result",
        "meets_approval_threshold",
        "requested_ada",
        "requested_dollars",
        "status",
        "fund_depletion",
        "not_funded_reason",
        "ada_to_be_payed",
        "lovelace_to_be_payed",
        "link_to_ideascale"
    )
)


def calc_results(
        proposals: Dict[str, Proposal],
        voteplan_proposals: Dict[str, ProposalStatus],
        fund: float,
        conversion_factor: float,
        threshold: float,
) -> List[Result]:
    success_results = calc_vote_difference_and_threshold_success(proposals, voteplan_proposals, threshold)
    sorted_ids = sorted(success_results.keys(), key=lambda x: success_results[x][0], reverse=True)
    result_lst = []
    depletion = fund
    for proposal_id in sorted_ids:
        proposal = proposals[proposal_id]
        voteplan_proposal = voteplan_proposals[proposal_id]
        total_result, threshold_success = success_results[proposal_id]
        yes_result, no_result = extract_yes_no_votes(proposal, voteplan_proposal)
        funded = all((threshold_success, depletion > 0, depletion >= proposal.proposal_funds))
        not_funded_reason = "" if funded else ( APPROVAL_THRESHOLD if not threshold_success else OVER_BUDGET)
        if funded:
            depletion -= proposal.proposal_funds
        ada_to_be_payed = proposal.proposal_funds*conversion_factor if funded else 0
        result = Result(
            proposal=proposal.proposal_title,
            yes=yes_result,
            no=no_result,
            result=total_result,
            meets_approval_threshold=YES if threshold_success else NO,
            requested_ada=proposal.proposal_funds*conversion_factor,
            requested_dollars=proposal.proposal_funds,
            status=FUNDED if funded else NOT_FUNDED,
            fund_depletion=depletion,
            not_funded_reason=not_funded_reason,
            ada_to_be_payed=ada_to_be_payed,
            lovelace_to_be_payed=ada_to_be_payed*LOVELACE_FACTOR,
            link_to_ideascale=proposal.proposal_url,
        )
        result_lst.append(result)

    return result_lst


if __name__ == "__main__":
    import asyncio
    from pprint import pprint
    vit_station_url: str = "https://servicing-station.vit.iohk.io"
    proposals, voteplans = asyncio.run(get_proposals_and_voteplans(vit_station_url))
    pprint(proposals)
    pprint(voteplans)
    assert set(proposals.keys()) == set(voteplans.keys())