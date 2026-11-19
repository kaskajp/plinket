import { createHash } from 'node:crypto';

const graphqlURL = 'https://api.linear.app/graphql';
const upstreamTimeout = 15_000;

export class LinearRelay {
  constructor({ apiKey, teamID, projectID, triageStateID, fetcher = fetch }) {
    this.apiKey = apiKey;
    this.teamID = teamID;
    this.projectID = projectID;
    this.triageStateID = triageStateID;
    this.fetcher = fetcher;
    this.pending = new Map();
  }

  async submit(report) {
    const id = issueID(report.id);
    if (this.pending.has(id)) return this.pending.get(id);
    const task = this.createReport(id, report);
    this.pending.set(id, task);
    try {
      await task;
    } finally {
      this.pending.delete(id);
    }
  }

  async graphql(query, variables) {
    const response = await this.fetcher(graphqlURL, {
      method: 'POST',
      headers: { Authorization: this.apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({ query, variables }),
      signal: AbortSignal.timeout(upstreamTimeout),
      redirect: 'error',
    });
    if (!response.ok) throw new Error('Linear request failed');
    const body = await response.json();
    if (body.errors?.length || !body.data) throw new Error('Linear rejected request');
    return body.data;
  }

  async exists(id) {
    const data = await this.graphql(`query FeedbackExists($id: ID!, $team: ID!) {
      issues(first: 1, filter: { id: { eq: $id }, team: { id: { eq: $team } } }) {
        nodes { id project { id } }
      }
    }`, { id, team: this.teamID });
    const issue = data.issues?.nodes?.[0];
    return issue?.id === id && issue?.project?.id === this.projectID;
  }

  async uploadScreenshot(data, index) {
    const filename = `screenshot-${index + 1}.jpg`;
    const result = await this.graphql(`mutation FeedbackUpload($size: Int!, $filename: String!) {
      fileUpload(contentType: "image/jpeg", filename: $filename, size: $size) {
        success uploadFile { uploadUrl assetUrl headers { key value } }
      }
    }`, { size: data.length, filename });
    const upload = result.fileUpload?.uploadFile;
    if (!result.fileUpload?.success || !upload) throw new Error('Screenshot upload unavailable');
    const uploadURL = new URL(upload.uploadUrl);
    const assetURL = new URL(upload.assetUrl);
    if (uploadURL.protocol !== 'https:' || assetURL.protocol !== 'https:') throw new Error('Invalid upload URL');
    const headers = Object.fromEntries((upload.headers ?? []).map(({ key, value }) => [key, value]));
    const response = await this.fetcher(uploadURL, {
      method: 'PUT', headers: { 'Content-Type': 'image/jpeg', ...headers }, body: data,
      signal: AbortSignal.timeout(upstreamTimeout), redirect: 'error',
    });
    if (!response.ok) throw new Error('Screenshot upload failed');
    return `![Screenshot ${index + 1}](<${assetURL.href.replaceAll('>', '%3E')}>)`;
  }

  async createReport(id, report) {
    if (await this.exists(id)) return;
    const screenshots = [];
    for (const [index, screenshot] of report.screenshots.entries()) {
      screenshots.push(await this.uploadScreenshot(screenshot, index));
    }
    const description = [
      report.details,
      ...screenshots,
      '---',
      `App: ${report.appVersion}`,
      `Platform: ${report.platform}`,
      `OS: ${report.osVersion}`,
      `Locale: ${report.locale}`,
      `Report ID: ${report.id}`,
    ].join('\n\n');
    try {
      const data = await this.graphql(`mutation FeedbackCreate($input: IssueCreateInput!) {
        issueCreate(input: $input) { success issue { id } }
      }`, { input: {
        id, title: `[In-app Feedback] ${report.title}`, description,
        teamId: this.teamID, projectId: this.projectID, stateId: this.triageStateID,
      } });
      if (!data.issueCreate?.success || data.issueCreate?.issue?.id !== id) {
        throw new Error('Issue creation not confirmed');
      }
    } catch (error) {
      // A lost mutation response or a concurrent retry can still mean the issue was created.
      if (await this.exists(id)) return;
      throw error;
    }
  }
}

export function issueID(reportID) {
  const bytes = createHash('sha256').update(`plinket-feedback-v1:${reportID.toLowerCase()}`).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
