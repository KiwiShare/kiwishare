import React, { useCallback, useEffect, useState } from 'react';
import { CheckCircle2, Flag, Loader2, XCircle } from 'lucide-react';
import { adminApi, AdminReport } from '../api/client';

export const AdminReportsPanel: React.FC = () => {
  const [reports, setReports] = useState<AdminReport[]>([]);
  const [status, setStatus] = useState('all');
  const [loading, setLoading] = useState(true);
  const [updatingId, setUpdatingId] = useState<string | null>(null);

  const loadReports = useCallback(async () => {
    try {
      setLoading(true);
      const res = await adminApi.getReports({ status });
      setReports(res.reports || []);
    } finally {
      setLoading(false);
    }
  }, [status]);

  useEffect(() => {
    loadReports();
  }, [loadReports]);

  const updateStatus = async (
    reportId: string,
    nextStatus: 'reviewed' | 'dismissed'
  ) => {
    try {
      setUpdatingId(reportId);
      await adminApi.updateReportStatus(reportId, nextStatus);
      await loadReports();
    } catch (error: any) {
      alert(error.message || 'Failed to update report.');
    } finally {
      setUpdatingId(null);
    }
  };

  return (
    <div className="animate-fade-in">
      <div
        className="glass-card"
        style={{
          padding: '20px',
          marginBottom: '20px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          gap: '16px',
          flexWrap: 'wrap',
        }}
      >
        <div>
          <h2
            style={{
              fontSize: '1.2rem',
              fontWeight: 800,
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
            }}
          >
            <Flag size={20} color="var(--primary-600)" />
            Mobile safety reports
          </h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.86rem' }}>
            Review report content submitted from the mobile app and record the moderation outcome.
          </p>
        </div>
        <select
          className="input"
          value={status}
          onChange={(event) => setStatus(event.target.value)}
          style={{ width: '180px' }}
        >
          <option value="all">All reports</option>
          <option value="pending">Pending</option>
          <option value="reviewed">Approved</option>
          <option value="dismissed">Dismissed</option>
        </select>
      </div>

      <div className="glass-card" style={{ overflowX: 'auto' }}>
        {loading ? (
          <div style={{ padding: '48px', textAlign: 'center' }}>
            <Loader2
              size={28}
              color="var(--primary-600)"
              style={{ animation: 'spin 1s linear infinite' }}
            />
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '980px' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border-subtle)', textAlign: 'left' }}>
                <th style={{ padding: '14px 16px' }}>Submitted</th>
                <th style={{ padding: '14px 16px' }}>Reporter</th>
                <th style={{ padding: '14px 16px' }}>Target</th>
                <th style={{ padding: '14px 16px' }}>Reason</th>
                <th style={{ padding: '14px 16px' }}>Details</th>
                <th style={{ padding: '14px 16px' }}>Status</th>
                <th style={{ padding: '14px 16px' }}>Decision</th>
              </tr>
            </thead>
            <tbody>
              {reports.map((report) => (
                <tr
                  key={report.id}
                  style={{
                    borderBottom: '1px solid var(--border-subtle)',
                    verticalAlign: 'top',
                  }}
                >
                  <td style={{ padding: '14px 16px', whiteSpace: 'nowrap', fontSize: '0.82rem' }}>
                    {new Date(report.createdAt).toLocaleString()}
                  </td>
                  <td style={{ padding: '14px 16px', fontFamily: 'monospace', fontSize: '0.76rem' }}>
                    {report.reporterId || 'Unknown'}
                  </td>
                  <td style={{ padding: '14px 16px', fontSize: '0.82rem' }}>
                    <strong style={{ textTransform: 'capitalize' }}>{report.targetType}</strong>
                    <div style={{ color: 'var(--text-muted)', fontFamily: 'monospace', fontSize: '0.74rem' }}>
                      {report.targetId || 'General'}
                    </div>
                  </td>
                  <td style={{ padding: '14px 16px', fontSize: '0.84rem', textTransform: 'capitalize' }}>
                    {report.reason.replaceAll('_', ' ')}
                  </td>
                  <td style={{ padding: '14px 16px', maxWidth: '360px', whiteSpace: 'pre-wrap', fontSize: '0.84rem' }}>
                    {report.details}
                  </td>
                  <td style={{ padding: '14px 16px', textTransform: 'capitalize', fontWeight: 700 }}>
                    {report.status === 'reviewed' ? 'Approved' : report.status}
                  </td>
                  <td style={{ padding: '14px 16px' }}>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        className="btn"
                        disabled={updatingId === report.id || report.status === 'reviewed'}
                        onClick={() => updateStatus(report.id, 'reviewed')}
                        style={{ background: '#dcfce7', color: '#166534', padding: '7px 10px' }}
                      >
                        <CheckCircle2 size={15} /> Approve
                      </button>
                      <button
                        className="btn"
                        disabled={updatingId === report.id || report.status === 'dismissed'}
                        onClick={() => updateStatus(report.id, 'dismissed')}
                        style={{ background: '#f1f5f9', color: '#475569', padding: '7px 10px' }}
                      >
                        <XCircle size={15} /> Dismiss
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {reports.length === 0 && (
                <tr>
                  <td colSpan={7} style={{ padding: '44px 16px', textAlign: 'center', color: 'var(--text-muted)' }}>
                    No reports match this filter.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};
