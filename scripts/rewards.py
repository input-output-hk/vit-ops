from typing import Dict, Optional, List, Union, Tuple

import pydantic
import httpx

# VIT servicing station models


class ProposalCategory(pydantic.BaseModel):
    category_id: str
    category_name: str
    category_description: str


class Proposer(pydantic.BaseModel):
    proposer_name: str
    proposer_email: str
    proposer_url: str
    proposer_relevant_experience: str


class Proposal(pydantic.BaseModel):
    internal_id: int
    proposal_id: str
    proposal_category: ProposalCategory
    proposal_title: str
    proposal_summary: str
    proposal_public_key: str
    proposal_funds: int
    proposal_url: str
    proposal_impact_score: int
    proposer: Proposer
    chain_proposal_id: str
    chain_proposal_index: int
    chain_vote_options: Dict[str, int]
    chain_voteplan_id: str
    chain_vote_start_time: str
    chain_vote_end_time: str
    chain_committee_end_time: str
    chain_voteplan_payload: str
    chain_vote_encryption_key: str
    fund_id: int
    challenge_id: int
    challenge_type: str
    proposal_solution: Optional[str]
    proposal_brief: Optional[str]
    proposal_importance: Optional[str]
    proposal_goal: Optional[str]
    proposal_metrics: Optional[str]


# Jormungandr models

class Options(pydantic.BaseModel):
    start: int
    end: int


class TallyResult(pydantic.BaseModel):
    results: List[int]
    options: Options


class VoteProposalStatus(pydantic.BaseModel):
    index: int
    proposal_id: str
    options: Options
    tally: Optional[TallyResult]
    votes_cast: int


class VoteplanStatus(pydantic.BaseModel):
    id: str
    payload: str
    proposals: List[VoteProposalStatus]


async def get_proposals(vit_servicing_station_url: str) -> [Proposal]:
    async with httpx.AsyncClient() as client:
        proposals_result = await client.get(f"{vit_servicing_station_url}/api/v0/proposals")
        assert proposals_result.status_code == 200
        return [Proposal(**proposal_data) for proposal_data in proposals_result.json()]


async def get_active_voteplans(vit_servicing_station_url: str) -> [VoteplanStatus]:
    async with httpx.AsyncClient() as client:
        proposals_result = await client.get(f"{vit_servicing_station_url}/api/v0/vote/active/plans")
        assert proposals_result.status_code == 200
        return [VoteplanStatus(**proposal_data) for proposal_data in proposals_result.json()]


async def get_proposals_and_voteplans(vit_servicing_station_url: str) -> Tuple[List[Proposal], List[VoteplanStatus]]:
    proposals_task = asyncio.create_task(get_proposals(vit_servicing_station_url))
    voteplans_task = asyncio.create_task(get_active_voteplans(vit_servicing_station_url))

    proposals = await proposals_task
    voteplans = await voteplans_task
    return proposals, voteplans


if __name__ == "__main__":
    import asyncio
    from pprint import pprint
    vit_station_url: str = "https://servicing-station.vit.iohk.io"
    proposals, voteplans = asyncio.run(get_proposals_and_voteplans(vit_station_url))
    pprint(proposals)
    pprint(voteplans)