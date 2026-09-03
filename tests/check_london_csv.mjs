// Read-only synthetic report audit. Input: JSON {signals:[...],trades:[...]}
// obtained with PowerShell Import-Csv / ConvertTo-Json. Never edits reports.
let text = '';
for await (const chunk of process.stdin) text += chunk;
const data = JSON.parse(text.replace(/^\uFEFF/, ''));
let checks = 0;
const failures = [];
function check(ok, label) { checks++; if (!ok) failures.push(label); }
for (const t of data.trades) {
    const s = data.signals.find(s => s.candidate_id === t.candidate_id);
    check(!!s, 'signal_link');
    if (!s) continue;
    check(Object.keys(t).length === 54 && Object.keys(s).length === 39, 'schemas');
    check(t.schema_version === 'LRB_REPORT_V1' && s.schema_version === t.schema_version, 'version');
    check(t.config_hash === 'FE2CD588' && s.config_hash === t.config_hash, 'synthetic_config');
    for (const field of ['london_day', 'range_high', 'range_low', 'range_width', 'signal_bar_time', 'signal_close', 'breakout_distance', 'direction', 'actual_fill', 'original_r', 'target_r', 'submitted_tp', 'entry_deal_ticket', 'position_identifier']) {
        check(t[field] === s[field], field);
    }
    check(Math.abs(+t.range_high - t.range_low - t.range_width) < 1e-9, 'width');
    check(t.london_day === t.signal_bar_time.slice(0, 10).replaceAll('-', ''), 'synthetic_London_date');
    check(Math.abs((t.direction === 'LONG' ? +t.signal_close - t.range_high : +t.range_low - t.signal_close) - t.breakout_distance) < 1e-9, 'breakout');
    check(t.fill_time >= s.signal_known_time && s.signal_known_time > s.signal_bar_time, 'causality');
    check(Math.abs(Math.abs(t.actual_fill - t.submitted_initial_sl) - t.original_r) < 1e-9, 'actual_R');
    check(Math.abs(Math.abs(t.submitted_tp - t.actual_fill) - t.original_r * t.target_r) <= 0.00000501, 'tick_rounded_TP');
    check(t.submitted_initial_sl === s.submitted_sl, 'SL');
    check(Math.abs(+t.gross_profit + (+t.commission) + (+t.swap) + (+t.fee) - t.net_profit) < 0.005, 'net');
    check(Math.abs(t.net_profit / t.actual_initial_cash_risk - t.realized_r) < 0.00000051, 'realized_R');
    check(t.integrity_flags === 'NONE' && t.trade_status === 'FINALIZED', 'integrity');
    check(['EXPERT', 'WEEKEND_FLAT'].includes(t.exit_reason), 'exit_reason');
}
check(data.trades.length === 4 && data.signals.length === 4, 'rowcounts');
check(data.trades.filter(t => t.exit_reason === 'WEEKEND_FLAT').length === 1, 'weekend');
console.log('[LRB_CSV_VERIFY] ' + JSON.stringify({checks, failures, signalRows: data.signals.length, tradeRows: data.trades.length, synthetic: true}));
if (failures.length) process.exitCode = 1;
