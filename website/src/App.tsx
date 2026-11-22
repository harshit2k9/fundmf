import type { ReactElement } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';

import { Loading } from './components/ui';
import { useAuth } from './lib/auth';
import DashboardPage from './pages/Dashboard';
import LoginPage from './pages/Login';
import PendingPage from './pages/Pending';
import ProfilePage from './pages/Profile';
import SignupPage from './pages/Signup';
import TransactionsPage from './pages/Transactions';
import AdminClientDetailPage from './pages/admin/ClientDetail';
import AdminClientsPage from './pages/admin/Clients';
import AdminSyncPage from './pages/admin/Sync';

/** Landing route for the resolved session. */
function HomeRedirect() {
  const { status } = useAuth();
  if (status === 'admin') return <Navigate to="/admin/clients" replace />;
  return <Navigate to="/dashboard" replace />;
}

function InvestorOnly({ children }: { children: ReactElement }) {
  const { status } = useAuth();
  if (status === 'admin') return <Navigate to="/admin/clients" replace />;
  if (status === 'active') return children;
  if (status === 'pendingApproval' || status === 'unprovisioned') {
    return <Navigate to="/pending" replace />;
  }
  return <Navigate to="/login" replace />;
}

function AdminOnly({ children }: { children: ReactElement }) {
  const { status } = useAuth();
  if (status === 'admin') return children;
  if (status === 'active') return <Navigate to="/dashboard" replace />;
  if (status === 'pendingApproval' || status === 'unprovisioned') {
    return <Navigate to="/pending" replace />;
  }
  return <Navigate to="/login" replace />;
}

function PublicOnly({ children }: { children: ReactElement }) {
  const { status } = useAuth();
  if (status === 'admin') return <Navigate to="/admin/clients" replace />;
  if (status === 'active') return <Navigate to="/dashboard" replace />;
  if (status === 'pendingApproval' || status === 'unprovisioned') {
    return <Navigate to="/pending" replace />;
  }
  return children;
}

export default function App() {
  const { status } = useAuth();

  if (status === 'loading') {
    return (
      <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}>
        <Loading label="Starting Fundmf…" />
      </div>
    );
  }

  return (
    <Routes>
      <Route path="/" element={<HomeRedirect />} />

      <Route
        path="/login"
        element={
          <PublicOnly>
            <LoginPage />
          </PublicOnly>
        }
      />
      <Route
        path="/signup"
        element={
          <PublicOnly>
            <SignupPage />
          </PublicOnly>
        }
      />
      <Route
        path="/pending"
        element={
          status === 'pendingApproval' || status === 'unprovisioned' ? (
            <PendingPage />
          ) : (
            <Navigate to="/" replace />
          )
        }
      />

      <Route
        path="/dashboard"
        element={
          <InvestorOnly>
            <DashboardPage />
          </InvestorOnly>
        }
      />
      <Route
        path="/transactions"
        element={
          <InvestorOnly>
            <TransactionsPage />
          </InvestorOnly>
        }
      />
      <Route
        path="/profile"
        element={
          <InvestorOnly>
            <ProfilePage />
          </InvestorOnly>
        }
      />

      <Route
        path="/admin/clients"
        element={
          <AdminOnly>
            <AdminClientsPage />
          </AdminOnly>
        }
      />
      <Route
        path="/admin/clients/:email"
        element={
          <AdminOnly>
            <AdminClientDetailPage />
          </AdminOnly>
        }
      />
      <Route
        path="/admin/sync"
        element={
          <AdminOnly>
            <AdminSyncPage />
          </AdminOnly>
        }
      />

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
