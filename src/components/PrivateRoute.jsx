import React, { useContext } from 'react';
import { Navigate } from 'react-router-dom';
import { AuthContext } from '../contexts/AuthContext';

const PrivateRoute = ({ children }) => {
  const { user, loading } = useContext(AuthContext);

  if (loading) {
    return <div className="loading-container">Загрузка...</div>;
  }

  return user ? children : <Navigate to="/login" replace />;
};

export default PrivateRoute;

