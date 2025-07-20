+++
title = "7. Topbar Menu"
type = "dev-log"
tags = [
  "react", "react-bootstrap", "tsx",
  "frontend", "ui", "navigation", "layout", "auth", "component",
  "access_control"
]
+++

In this section, I'll explain how I implemented the topbar menu. I implemented this menu to test and operate various functions between backend and the worker services.

## 1. The design of the Topbar Menu

---

- To keep things simple, I used `react-bootstrap` for the UI components, as I'm not currently focused on visual design. I'll improve the visual styling in a future version after completing version 1 of this project.
- The topbar includes a set of menu items and a logout button.

### 1.1 Topbar Menu Structure

- To visualize the layout, I created a simple diagram of the topbar menu.

    ![topbar menu](/images/projects/mcttool/7-1.png)

As shown above, the topbar menu consists of three sections:

- **Project Name (Left)**: Displays the name or logo of the current project.  
  Clicking this section redirects the user to the dashboard page, which acts as the main landing page.

- **Menu Items (Center)**: The central navigation area, where links to various functional pages are placed.

- **Logout Button (Right)**: Ends the session and logs the administrator out of the system.

The topbar remains fixed at the top of the screen, while the page contents are rendered below it.

## 2. Frontend

---

### 2.1 Topbar.tsx

- This is the topbar component. I created this file in the '/src/components' directory.

    ```tsx
    import { Navbar, Nav, Container, Button } from 'react-bootstrap';
    import { useNavigate } from 'react-router';
    import './Topbar.module.css';
    import { useEffect } from 'react';

    const Topbar = () => { 
        const navigate = useNavigate();
        const access_token = localStorage.getItem('access_token');
        useEffect(() => {
        if (!access_token) {
        navigate('/login');
            }
        }, [access_token, navigate]);

        if (!access_token) return null;

        const handleLogout = () => {
            // Perform logout logic here, e.g., clear user session
            localStorage.removeItem('access_token'); // Clear the access token
            navigate('/login'); // Redirect to login page after logout
        };

        return (
            <Navbar bg="light" expand="lg" className="shadow-sm navbar-top">
            <Container fluid>
                <Navbar.Brand onClick={() => navigate('/dashboard')} style={{ cursor: 'pointer' }}>
                Crypto Auto Tool
                </Navbar.Brand>

                <Navbar.Toggle aria-controls="topbar-nav" />
                <Navbar.Collapse id="topbar-nav">
                <Nav className="ms-auto">
                    {access_token && (
                    <>
                        <Nav.Link onClick={() => navigate('/dashboard')}>Dashboard</Nav.Link>
                        <Nav.Link onClick={() => navigate('/logs')}>Logs</Nav.Link>
                        <Nav.Link onClick={() => navigate('/settings')}>Settings</Nav.Link>
                        <Button variant="outline-danger" size="sm" className="ms-2" onClick={handleLogout}>
                        Logout
                        </Button>
                    </>
                    )}
                    {!access_token && (
                    <Button variant="primary" size="sm" onClick={() => navigate('/login')}>
                        Login
                    </Button>
                    )}
                </Nav>
                </Navbar.Collapse>
            </Container>
            </Navbar>
        );
    };

    export default Topbar;
    ```

- If there is no access token stored in localStorage, the user is automatically redirected to the login page. This ensures that only authenticated users can access pages where the Topbar is rendered.
- The logout button removes the token from localStorage and redirects the user to the login screen.

### 2.2 Topbar.module.css

- This is the CSS module for styling the Topbar.

    ```css
    .navbar-top {
        position: fixed;
        top: 0;
        width: 100%;
        z-index: 1000;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    }
    ```

- This style ensures that the topbar stays fixed at the top of the viewport and always appears above other components.
- The box-shadow adds subtle depth, helping visually separate it from the page contents.

### 2.3 App.tsx

- To apply this topbar menu across all pages, I modified `App.tsx` to conditionally render it depending on the current route.

    ```tsx
    ...
    import Topbar from '@/components/Topbar'
    import { useLocation } from 'react-router'
    ...

    function App() {
    const location = useLocation();
    const hideTopbar = location.pathname === '/login';

    return (
        <>
        {!hideTopbar && <Topbar />}
        <div className="main-content">
            <Routes>
            ...
            </Routes>
        </div>
        </>
    )
    }

    export default App
    ```

- In this setup, the Topbar is hidden only on the login page(/login) and shown on all other routes. This keeps the login screen clean and focused, while maintaining consistent navigation elsewhere in the app.

## 3. Result

---

![topbar demo](/images/projects/mcttool/7-2.gif)
