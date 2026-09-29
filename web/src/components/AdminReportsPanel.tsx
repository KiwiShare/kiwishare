import React, { useCallback, useEffect, useState } from 'react';
import { AlertCircle, CheckCircle2, Flag, Loader2, XCircle } from 'lucide-react';
import { adminApi, AdminReport } from '../api/client';

type Notice = {
  kind: 'success' | 'error';
  message: string;
};

export const AdminReportsPanel: React.FC = () => {
  const [reports, setReports] = useState<AdminReport[]>([]);
  const [status, setStatus] = useState('all');
  const [loading, setLoading] = useState(true);
  const [updatingId, setUpdatingId] = useState<string | null>(null);
  const [updatingStatus, setUpdatingStatus] = useState<'reviewed' | 'dismissed' | null>(null);
  const [notice, setNotice] = useState<Notice | null>(null);

  const loadReports = useCallback(async (showLoading = true) => {
    try {
      if (showLoading) setLoading(true);
      const res = await adminApi.getReports({ status });
      setReports(res.reports || []);
    } catch (error: any) {
      setNotice({
        kind: 'error',
        message: error?.message || 'Failed to load reports.',
      });
    } finally {
      if (showLoading) setLoading(false);
    }
  }, [status]);

  useEffect(() => {
    setNotice(null);
    void loadReports();
  }, [loadReports]);

  const updateStatus = async (
    reportId: string,
    nextStatus: 'reviewed' | 'dismissed'
  ) => {
    if (updatingId) return;

    try {
      setUpdatingId(reportId);
      setUpdatingStatus(nextStatus);
      setNotice(null);

      const res = await adminApi.updateReportStatus(reportId, nextStatus);
      const savedStatus = res.report.status as AdminReport['status'];

      setReports((current) => {
        if (status !== 'all' && status !== savedStatus) {
          return current.filter((report) => report.id !== reportId);
        }
        return current.map((report) =>
          report.id === reportId ? { ...report, status: savedStatus } : report
        );
      });

      setNotice({
        kind: 'success',
        message:
          nextStatus === 'reviewed'
            ? 'Report approved successfully.'
            : 'Report dismissed successfully.',
      });

      // Revalidate in the background without replacing the table with a loading state.
      void loadReports(false);
    } catch (error: any) {
      setNotice({
        kind: 'error',
        message: error?.message || 'Failed to update report.',
      });
    } finally {
      setUpdatingId(null);
      setUpdatingStatus(null);
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

      {notice && (
        <div
          role={notice.kind === 'error' ? 'alert' : 'status'}
          aria-live="polite"
          style={{
            marginBottom: '16px',
            padding: '12px 14px',
            borderRadius: '12px',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            fontSize: '0.88rem',
            fontWeight: 700,
            background: notice.kind === 'success' ? '#dcfce7' : '#fee2e2',
            color: notice.kind === 'success' ? '#166534' : '#991b1b',
            border: notice.kind === 'success' ? '1px solid #bbf7d0' : '1px solid #fecaca',
          }}
        >
          {notice.kind === 'success' ? <CheckCircle2 size={17} /> : <AlertCircle size={17} />}
          {notice.message}
        </div>
      )}

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
              {reports.map((report) => {
                const isUpdating = updatingId === report.id;
                return (
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
                      {report.reason.replace(/_/g, ' ')}
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
                          disabled={updatingId !== null || report.status === 'reviewed'}
                          onClick={() => void updateStatus(report.id, 'reviewed')}
                          style={{ background: '#dcfce7', color: '#166534', padding: '7px 10px' }}
                        >
                          {isUpdating && updatingStatus === 'reviewed' ? (
                            <Loader2 size={15} style={{ animation: 'spin 1s linear infinite' }} />
                          ) : (
                            <CheckCircle2 size={15} />
                          )}
                          {isUpdating && updatingStatus === 'reviewed' ? 'Approving…' : 'Approve'}
                        </button>
                        <button
                          className="btn"
                          disabled={updatingId !== null || report.status === 'dismissed'}
                          onClick={() => void updateStatus(report.id, 'dismissed')}
                          style={{ background: '#f1f5f9', color: '#475569', padding: '7px 10px' }}
                        >
                          {isUpdating && updatingStatus === 'dismissed' ? (
                            <Loader2 size={15} style={{ animation: 'spin 1s linear infinite' }} />
                          ) : (
                            <XCircle size={15} />
                          )}
                          {isUpdating && updatingStatus === 'dismissed' ? 'Dismissing…' : 'Dismiss'}
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
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
