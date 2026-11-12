"use client";

import { useEffect, useState, useTransition } from "react";
import Link from "next/link";
import { signInAction } from "@/app/actions/auth";
import ProductCatalog from "@/components/ProductCatalog";
import {
  ArrowRight, ArrowUpRight, Award, BarChart3, Bell, CheckCircle2, ChevronDown,
  CircleHelp, ClipboardList, Coins, Crown, Eye, EyeOff, Gift, Globe2, Handshake,
  LayoutDashboard, LockKeyhole, LogOut, Menu, Network, Package, ShieldCheck,
  ShoppingBag, Sparkles, TrendingUp, Users, Wallet, X
} from "lucide-react";

type Role = "admin" | "distributor";
type Screen = "home" | "login" | "dashboard";

const money = (value: number) => new Intl.NumberFormat("en-PH", {
  style: "currency", currency: "PHP", maximumFractionDigits: 0
}).format(value);

export default function Home() {
  const [screen, setScreen] = useState<Screen>("home");
  const [role, setRole] = useState<Role>("distributor");
  const [showPassword, setShowPassword] = useState(false);
  const [mobileMenu, setMobileMenu] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [notice, setNotice] = useState("");
  const [isSigningIn, startTransition] = useTransition();

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const requestedPortal = params.get("portal");

    if (requestedPortal === "admin" || requestedPortal === "distributor") {
      setRole(requestedPortal);
      setScreen("login");
    }

    if (params.get("auth") === "not-configured") {
      setScreen("login");
      setNotice("Secure sign-in is not configured yet. Add the Supabase project URL and anon key, then try again.");
    }

    if (params.get("auth") === "pending") {
      setScreen("login");
      setNotice("Your email is confirmed. Your distributor application is now waiting for administrator approval.");
    }

    if (params.get("auth") === "confirmation-failed") {
      setScreen("login");
      setNotice("We could not confirm that email link. Request a new confirmation email or contact AMANAH support.");
    }
  }, []);

  const openLogin = (nextRole: Role) => {
    setRole(nextRole);
    setNotice("");
    setScreen("login");
    setMobileMenu(false);
  };

  const submitLogin = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    formData.set("role", role);
    setNotice("");

    startTransition(async () => {
      const result = await signInAction(formData);
      if (result && "error" in result) {
        setNotice(result.error);
      }
    });
  };

  if (screen === "dashboard") {
    return <Dashboard role={role} onLogout={() => setScreen("home")} />;
  }

  if (screen === "login") {
    return (
      <main className="login-shell">
        <button className="back-home" onClick={() => setScreen("home")}>← Back to AMANAH</button>
        <div className="login-layout">
          <section className="login-story">
            <Brand light />
            <div className="login-story-copy">
              <span className="eyebrow light-eyebrow">AMANAH NETWORK MANAGEMENT</span>
              <h1>Grow with purpose.<br /><em>Lead with integrity.</em></h1>
              <p>A clear view of your network, product activity, and performance—built around accountability and trust.</p>
              <div className="login-promise"><ShieldCheck size={18} /> Secure, role-based access</div>
            </div>
            <div className="login-bottom">AMANAH DMC <span>•</span> Built for people and progress</div>
          </section>
          <section className="login-panel">
            <div className="login-panel-inner">
              <span className="eyebrow">WELCOME BACK</span>
              <h2>Sign in to your<br />workspace.</h2>
              <p className="muted">Choose the portal that matches your account.</p>
              <div className="role-switch" aria-label="Choose account type">
                <button className={role === "distributor" ? "selected" : ""} onClick={() => { setRole("distributor"); setNotice(""); }}>
                  <Users size={17} /> Distributor
                </button>
                <button className={role === "admin" ? "selected" : ""} onClick={() => { setRole("admin"); setNotice(""); }}>
                  <ShieldCheck size={17} /> Administrator
                </button>
              </div>
              <div className="portal-label"><span className={role === "admin" ? "admin-dot" : "member-dot"} /> {role === "admin" ? "ADMINISTRATOR PORTAL" : "DISTRIBUTOR PORTAL"}</div>
              <form className="login-form" onSubmit={submitLogin}>
                <input type="hidden" name="role" value={role} />
                <label>{role === "admin" ? "Admin email" : "Distributor email"}</label>
                <input type="email" name="email" autoComplete="username" required value={email} onChange={e => setEmail(e.target.value)} placeholder={role === "admin" ? "admin@amanah.com" : "Enter your email address"} />
                <label>Password</label>
                <div className="password-field">
                  <input name="password" autoComplete="current-password" required minLength={6} type={showPassword ? "text" : "password"} value={password} onChange={e => setPassword(e.target.value)} placeholder="Enter your password" />
                  <button type="button" aria-label="Toggle password visibility" onClick={() => setShowPassword(!showPassword)}>{showPassword ? <EyeOff size={18} /> : <Eye size={18} />}</button>
                </div>
                <div className="form-extras"><span className="muted">Use your registered email address.</span><button type="button" className="text-button" onClick={() => setNotice("Password recovery is not enabled yet. Contact your AMANAH administrator.")}>Forgot password?</button></div>
                <button className="primary-button full-button" type="submit" disabled={isSigningIn}>{isSigningIn ? "Signing in..." : "Sign in"} <ArrowRight size={17} /></button>
              </form>
              {notice && <div className="notice" role="status" aria-live="polite"><CircleHelp size={17} /><span>{notice}</span></div>}
              <div className="login-help">Need access? <Link className="text-button" href="/register">Create a distributor account</Link></div>
              <button type="button" className="text-button" onClick={() => setScreen("dashboard")}>Preview sample dashboard</button>
              <div className="login-security"><LockKeyhole size={14} /> Sign-in checks your active AMANAH profile and assigned role.</div>
            </div>
          </section>
        </div>
      </main>
    );
  }

  return (
    <main>
      <header className="site-header">
        <div className="nav-wrap">
          <Brand />
          <nav className={mobileMenu ? "nav-links open" : "nav-links"}>
            <a href="#about" onClick={() => setMobileMenu(false)}>About</a>
            <a href="#platform" onClick={() => setMobileMenu(false)}>Platform</a>
            <a href="#principles" onClick={() => setMobileMenu(false)}>Our principles</a>
            <button className="nav-login" onClick={() => openLogin("distributor")}>Member login <ArrowUpRight size={15} /></button>
            <button className="nav-admin" onClick={() => openLogin("admin")}>Admin portal</button>
          </nav>
          <button className="mobile-toggle" aria-label="Toggle navigation" onClick={() => setMobileMenu(!mobileMenu)}>{mobileMenu ? <X /> : <Menu />}</button>
        </div>
      </header>

      <section className="hero">
        <div className="hero-grid">
          <div className="hero-copy">
            <span className="eyebrow"><span className="eyebrow-line" /> A NETWORK BUILT ON TRUST</span>
            <h1>Build together.<br /><em>Flourish together.</em></h1>
            <p className="hero-lead">A smarter way to manage your AMANAH journey. Stay connected to your team, track real product activity, and see your progress with clarity.</p>
            <div className="hero-actions">
              <button className="primary-button" onClick={() => openLogin("distributor")}>Enter member portal <ArrowRight size={17} /></button>
              <a className="secondary-link" href="#platform">Explore the platform <ArrowUpRight size={16} /></a>
            </div>
            <div className="hero-trust"><span><ShieldCheck size={16} /> Transparent tracking</span><span><Network size={16} /> Connected community</span></div>
          </div>
          <div className="hero-art">
            <div className="orbit orbit-one" /><div className="orbit orbit-two" />
            <div className="hero-emblem"><div className="emblem-mark">A</div><span>AMANAH</span><small>GROW WITH INTEGRITY</small></div>
            <div className="float-card card-top"><span className="float-icon"><TrendingUp size={17} /></span><div><small>NETWORK MOMENTUM</small><strong>Growing together</strong></div></div>
            <div className="float-card card-bottom"><span className="float-icon gold"><Award size={17} /></span><div><small>YOUR JOURNEY</small><strong>Progress with purpose</strong></div></div>
            <div className="art-caption">TRUST <i>•</i> SERVICE <i>•</i> GROWTH</div>
          </div>
        </div>
        <div className="hero-footer"><span>01 / BUILT FOR YOUR NEXT CHAPTER</span><span>SCROLL TO DISCOVER ↓</span></div>
      </section>

      <section className="intro-section" id="about">
        <div className="section-kicker">THE AMANAH APPROACH</div>
        <div className="intro-grid"><h2>More than numbers.<br /><em>A network of people.</em></h2><p>AMANAH brings your day-to-day network operations into one organized workspace. From member activity to product orders and performance summaries, the goal is simple: make information easier to understand and decisions easier to make.</p></div>
        <div className="principle-strip" id="principles"><div><ShieldCheck /><strong>Accountability</strong><span>Clear records and responsible access.</span></div><div><Handshake /><strong>Community</strong><span>Support for every step of the journey.</span></div><div><TrendingUp /><strong>Progress</strong><span>Performance grounded in real activity.</span></div></div>
      </section>

      <section className="platform-section" id="platform">
        <div className="platform-heading"><div><div className="section-kicker">ONE PLATFORM, CLEARER WORKFLOWS</div><h2>Everything in its<br /><em>right place.</em></h2></div><p>Separate workspaces for the people who manage the system and the members who grow within it.</p></div>
        <div className="portal-cards">
          <article className="portal-card distributor-card"><div className="portal-card-top"><span className="portal-icon"><Users /></span><span className="portal-number">01 / MEMBER</span></div><h3>Distributor<br />workspace</h3><p>Follow your personal activity, understand your team volume, review orders, and keep track of your commissions and wallet.</p><ul><li><CheckCircle2 /> Personal and group performance</li><li><CheckCircle2 /> Team and genealogy overview</li><li><CheckCircle2 /> Orders, wallet and statements</li></ul><button className="card-link" onClick={() => openLogin("distributor")}>Distributor login <ArrowRight size={17} /></button></article>
          <article className="portal-card admin-card"><div className="portal-card-top"><span className="portal-icon"><ShieldCheck /></span><span className="portal-number">02 / OPERATIONS</span></div><h3>Administrator<br />console</h3><p>Oversee member accounts, product catalog, order verification, monthly qualification, and financial controls.</p><ul><li><CheckCircle2 /> Member and sponsor management</li><li><CheckCircle2 /> Product, order and refund controls</li><li><CheckCircle2 /> Commission review and audit trail</li></ul><button className="card-link" onClick={() => openLogin("admin")}>Admin login <ArrowRight size={17} /></button></article>
        </div>
      </section>

      <section className="closing-section"><div className="closing-mark">A</div><div className="section-kicker">YOUR AMANAH JOURNEY STARTS HERE</div><h2>Clarity creates confidence.<br /><em>Integrity creates lasting growth.</em></h2><button className="primary-button" onClick={() => openLogin("distributor")}>Go to member login <ArrowRight size={17} /></button></section>
      <footer className="site-footer"><Brand light /><span>© {new Date().getFullYear()} AMANAH DMC. All rights reserved.</span><span>Built on trust. Managed with care.</span></footer>
    </main>
  );
}

function Brand({ light = false }: { light?: boolean }) {
  return <div className={light ? "brand brand-light" : "brand"}><span className="brand-symbol">A</span><span className="brand-name">AMANAH<small>DMC NETWORK</small></span></div>;
}

function Dashboard({ role, onLogout }: { role: Role; onLogout: () => void }) {
  const admin = role === "admin";
  const [active, setActive] = useState("Overview");
  const nav = admin
    ? [{ label: "Overview", icon: LayoutDashboard }, { label: "Members", icon: Users }, { label: "Products", icon: Package }, { label: "Orders", icon: ShoppingBag }, { label: "Commissions", icon: Coins }, { label: "Payouts", icon: Wallet }]
    : [{ label: "Overview", icon: LayoutDashboard }, { label: "My network", icon: Network }, { label: "My orders", icon: ShoppingBag }, { label: "Commissions", icon: Coins }, { label: "My wallet", icon: Wallet }, { label: "Rewards", icon: Gift }];
  return (
    <main className="dashboard-shell">
      <aside className="dash-sidebar"><Brand /><div className="dash-label">WORKSPACE</div><div className="dash-nav">{nav.map(item => <button key={item.label} className={active === item.label ? "active" : ""} onClick={() => setActive(item.label)}><item.icon size={18} />{item.label}</button>)}</div><div className="sidebar-bottom"><div className="support-box"><CircleHelp size={18} /><strong>Need help?</strong><span>Our support team is here for you.</span></div><button className="logout-button" onClick={onLogout}><LogOut size={17} /> Exit preview</button></div></aside>
      <section className="dash-main"><header className="dash-header"><div><span className="section-kicker">{admin ? "ADMINISTRATION" : "MEMBER PORTAL"}</span><h1>{active}</h1></div><div className="dash-user"><button className="notification-button"><Bell size={18} /><i /></button><div className="avatar">{admin ? "AD" : "JD"}</div><div><strong>{admin ? "Administrator" : "Juan Dela Cruz"}</strong><small>{admin ? "System manager" : "Distributor account"}</small></div><ChevronDown size={15} /></div></header>
        {active === "Products" ? <ProductCatalog /> : <>
        <div className="welcome-banner"><div><span>{admin ? "AMANAH OPERATIONS" : "YOUR AMANAH JOURNEY"}</span><h2>{admin ? "Good day, Administrator." : "Welcome back, Juan."}</h2><p>{admin ? "Here is your system activity at a glance." : "Keep building with purpose. Here is your latest performance snapshot."}</p></div><div className="welcome-symbol"><Crown size={48} /></div></div>
        <div className="dash-stat-grid">{(admin ? [{ label: "Total members", value: "1,248", change: "+8.2% this month", icon: Users }, { label: "Verified orders", value: "386", change: "This month", icon: ShoppingBag }, { label: "Sales volume", value: money(482500), change: "Eligible product sales", icon: BarChart3 }, { label: "Pending reviews", value: "12", change: "Requires attention", icon: ClipboardList }] : [{ label: "Personal PV", value: "150 PV", change: "This month", icon: Sparkles }, { label: "Group PV", value: "3,420 PV", change: "This month", icon: Network }, { label: "Commission balance", value: money(8420), change: "Illustrative preview", icon: Coins }, { label: "My team", value: "48", change: "Active and pending", icon: Users }]).map((stat, i) => <div className="dash-stat" key={stat.label}><div className="stat-top"><span>{stat.label}</span><i><stat.icon size={17} /></i></div><strong>{stat.value}</strong><small className={i === 3 && admin ? "attention" : ""}>{stat.change}</small></div>)}</div>
        <div className="dash-content-grid"><section className="dash-panel"><div className="panel-heading"><div><span className="section-kicker">PERFORMANCE</span><h3>{admin ? "Monthly business overview" : "Your volume overview"}</h3></div><button className="period-select">This month <ChevronDown size={14} /></button></div><div className="chart-placeholder"><div className="chart-y"><span>5k</span><span>4k</span><span>3k</span><span>2k</span><span>1k</span></div><div className="chart-area"><div className="chart-lines"><i /><i /><i /><i /><i /></div><svg viewBox="0 0 600 190" preserveAspectRatio="none" aria-label="Illustrative monthly trend"><defs><linearGradient id="area" x1="0" x2="0" y1="0" y2="1"><stop offset="0%" stopColor="#b58c4c" stopOpacity=".25" /><stop offset="100%" stopColor="#b58c4c" stopOpacity="0" /></linearGradient></defs><path d="M0 150 C45 130 60 145 100 118 S170 132 205 95 S270 115 310 78 S375 100 410 62 S480 83 520 43 S565 56 600 25 L600 190 L0 190Z" fill="url(#area)" /><path d="M0 150 C45 130 60 145 100 118 S170 132 205 95 S270 115 310 78 S375 100 410 62 S480 83 520 43 S565 56 600 25" fill="none" stroke="#a77b38" strokeWidth="3" vectorEffect="non-scaling-stroke" /></svg><div className="chart-x"><span>Wk 1</span><span>Wk 2</span><span>Wk 3</span><span>Wk 4</span></div></div></div><div className="chart-foot"><span><i className="legend-dot" /> {admin ? "Verified product sales" : "Eligible group PV"}</span><span>Illustrative dashboard data</span></div></section>
          <section className="dash-panel activity-panel"><div className="panel-heading"><div><span className="section-kicker">LATEST UPDATES</span><h3>Recent activity</h3></div><button className="view-all" onClick={() => setActive(admin ? "Orders" : "My orders")}>View all <ArrowUpRight size={14} /></button></div>{(admin ? [{ icon: Users, title: "New member registration", sub: "Pending account review", time: "Today, 10:42 AM" }, { icon: ShoppingBag, title: "Order submitted", sub: "Awaiting payment verification", time: "Today, 9:18 AM" }, { icon: ClipboardList, title: "Monthly review", sub: "Commission run is in draft", time: "Yesterday" }] : [{ icon: Coins, title: "Commission statement", sub: "Monthly preview updated", time: "Today, 10:42 AM" }, { icon: ShoppingBag, title: "Order received", sub: "Order status: processing", time: "Yesterday" }, { icon: Users, title: "Team member joined", sub: "Your network has a new member", time: "Nov 8" }]).map((a, i) => <div className="activity-row" key={a.title}><span className="activity-icon"><a.icon size={17} /></span><div><strong>{a.title}</strong><small>{a.sub}</small></div><time>{a.time}</time></div>)}</section></div>
        <div className="dash-disclaimer"><ShieldCheck size={16} /><span>Preview environment. Figures and activities shown are sample data only. Financial balances and commissions will appear only after verified transactions and approved system calculations.</span></div>
        </>}
      </section>
    </main>
  );
}
