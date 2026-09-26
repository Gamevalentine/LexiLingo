import React, { Suspense, lazy } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import { BookOpen, Bot, FileText, Languages, Layers } from "lucide-react";
import { I18nProvider, useI18n } from "./lib/i18n";
import { AuthProvider, useAuth } from "./components/AuthProvider";
import { RequireAuth } from "./components/RequireAuth";
import { RequireRole } from "./components/RequireRole";
import { AppShell, NavItem } from "./components/AppShell";

const LoginPage = lazy(() => import("./pages/LoginPage").then((m) => ({ default: m.LoginPage })));
const RoleRedirectPage = lazy(() => import("./pages/RoleRedirectPage").then((m) => ({ default: m.RoleRedirectPage })));
const CoursesPage = lazy(() => import("./pages/CoursesPage").then((m) => ({ default: m.CoursesPage })));
const UnitsPage = lazy(() => import("./pages/UnitsPage").then((m) => ({ default: m.UnitsPage })));
const LessonsPage = lazy(() => import("./pages/LessonsPage").then((m) => ({ default: m.LessonsPage })));
const LessonExercisesPage = lazy(() => import("./pages/LessonExercisesPage").then((m) => ({ default: m.LessonExercisesPage })));
const VocabularyPage = lazy(() => import("./pages/VocabularyPage").then((m) => ({ default: m.VocabularyPage })));
const AiChatSettingsPage = lazy(() => import("./pages/AiChatSettingsPage").then((m) => ({ default: m.AiChatSettingsPage })));
const NoAccessPage = lazy(() => import("./pages/NoAccessPage").then((m) => ({ default: m.NoAccessPage })));
const NotFoundPage = lazy(() => import("./pages/NotFoundPage").then((m) => ({ default: m.NotFoundPage })));

const PageLoader = () => (
  <div className="flex items-center justify-center h-full p-8">
    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
  </div>
);

const AppRoutes = () => {
  const { t } = useI18n();
  const { role } = useAuth();
  const shellRole = role === "super_admin" ? "super_admin" : "admin";

  const navItems: NavItem[] = [
    { to: "/admin/courses", label: t.nav.courses, icon: <BookOpen size={18} /> },
    { to: "/admin/units", label: t.nav.units, icon: <Layers size={18} /> },
    { to: "/admin/lessons", label: t.nav.lessons, icon: <FileText size={18} /> },
    { to: "/admin/vocabulary", label: t.nav.vocabulary, icon: <Languages size={18} /> },
    { to: "/admin/ai-chat", label: "Lexi AI", icon: <Bot size={18} /> },
  ];

  return (
    <Suspense fallback={<PageLoader />}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/no-access" element={<NoAccessPage />} />

        <Route element={<RequireAuth />}>
          <Route path="/" element={<RoleRedirectPage />} />
          <Route element={<RequireRole allowed={["admin", "super_admin"]} />}>
            <Route
              element={
                <AppShell
                  title="LexiLingo Admin"
                  role={shellRole}
                  navItems={navItems}
                />
              }
            >
              <Route path="/admin" element={<Navigate to="/admin/courses" replace />} />
              <Route path="/admin/courses" element={<CoursesPage />} />
              <Route path="/admin/courses/:courseId/units" element={<UnitsPage />} />
              <Route path="/admin/courses/:courseId/units/:unitId/lessons" element={<LessonsPage />} />
              <Route
                path="/admin/courses/:courseId/units/:unitId/lessons/:lessonId/exercises"
                element={<LessonExercisesPage />}
              />
              <Route path="/admin/units" element={<UnitsPage />} />
              <Route path="/admin/lessons" element={<LessonsPage />} />
              <Route path="/admin/vocabulary" element={<VocabularyPage />} />
              <Route path="/admin/ai-chat" element={<AiChatSettingsPage />} />
            </Route>
          </Route>
        </Route>

        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </Suspense>
  );
};

const App = () => (
  <I18nProvider>
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  </I18nProvider>
);

export default App;
