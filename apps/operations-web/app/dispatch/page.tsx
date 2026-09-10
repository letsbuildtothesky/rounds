import {PickupIssueConnection} from '../pickup-issues/pickup-issue-connection';
import {operationsConnectionConfig} from '../../src/v23/operations-connection-config';
import '../../src/v23/pickup-issue-drawer.css';
import '../../src/v23/dispatch-workspace.css';
import 'mapbox-gl/dist/mapbox-gl.css';
import '../../src/v23/dispatch-map.css';

/** First Phase39-mounted workflow. Same verified-login controller/journal;
 * default-off, never a legacy tenant conversion or sample-board fallback. */
export default function DispatchPage() {
  return <PickupIssueConnection layout="board" config={operationsConnectionConfig(process.env)}/>;
}
import '../../src/v23/manual-intake-form.css';
