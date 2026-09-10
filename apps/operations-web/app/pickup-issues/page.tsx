import {PickupIssueConnection} from './pickup-issue-connection';
import {operationsConnectionConfig} from '../../src/v23/operations-connection-config';
import '../../src/v23/pickup-issue-drawer.css';

/** Explicit isolated connection. No legacy-ID conversion or default cutover. */
export default function PickupIssuesPage() {
  return <PickupIssueConnection config={operationsConnectionConfig(process.env)}/>;
}
