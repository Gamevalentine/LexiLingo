import React from "react";
import { Navigate } from "react-router-dom";
import { useAuth } from "../components/AuthProvider";

export const RoleRedirectPage = () => {
  const { role } = useAuth();

  if (role === "super_admin" || role === "admin") {
    return <Navigate to="/admin/courses" replace />;
  }

  return <Navigate to="/no-access" replace />;
};
