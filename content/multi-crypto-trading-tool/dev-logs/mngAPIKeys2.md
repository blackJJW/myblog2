+++
title = "11. Managing API Keys - Frontend Implementation"
type = "dev-log"
tags = [
  "react", "react-bootstrap", "frontend", "typescript", "axios",
  "component", "settings-page", "api-key-management", "api-keys",
  "jwt", "security", "access-control", "modal", "pagination"
]
weight = 11
+++

This post outlines the frontend design and implementation for API key management.

## 1. The design of the API Key Management

---

### 1.1 API Key Management Structure

- To visualize the layout, I sketched a simple diagram of the API Key management page.

    ![api key mng design](/images/projects/mcttool/11-1.png)

- **Left-side Menu Items**: Under **Settings**, several submenus are available.
- **Exchanges**: Area for managing exchanges.
- **API Keys**: Area for managing API keys.

The sidebar stays fixed on the left, and the content area renders on the right.

## 2. Frontend

---

### 2.1 SettingsSideBar.tsx

- This component renders the sidebar menu.
- The menu currently includes an **API Keys** item for navigating to the key-management view.
- Clicking a menu item renders the corresponding content.

    ```tsx
    import { ListGroup } from "react-bootstrap";

    type SettingsSidebarProps = {
        selected: string;
        onSelect: (key: string) => void;
    };

    const SettingsSidebar = ({ selected, onSelect }: SettingsSidebarProps) => {
        return (
            <div className="bg-light vh-100 border-end p-3">
                <h5>Settings</h5>
                <ListGroup>
                    <ListGroup.Item
                        active={selected === "API Keys"}
                        onClick={() => onSelect("API Keys")}
                        style={({ cursor: "pointer" })}
                    >API Keys</ListGroup.Item>
                </ListGroup>
            </div>
        )
    }

    export default SettingsSidebar;
    ```

### 2.2 ExchangeList.tsx

- This component displays the list of exchanges returned by the backend.
- A + Add button creates a new exchange. Deletion will be added later.

    ```tsx
    import { ListGroup, Button } from "react-bootstrap";

    type ExchangeListProps = {
        exchanges: { exchange_id: number; exchange_name: string }[];
        selectedExchange: string;
        onSelectExchange: (exchange: { exchange_id: number; exchange_name: string }) => void;
        onAddExchange?: () => void;
    };

    const ExchangeList = ({ 
        exchanges, 
        selectedExchange, 
        onSelectExchange, 
        onAddExchange 
    }: ExchangeListProps) => {
        return (
            <div>
            <div className="d-flex justify-content-between align-items-center mb-2">
                <h5>Exchanges</h5>
                <Button variant="outline-primary" size="sm" onClick={onAddExchange}>+ Add</Button>
            </div>
            <ListGroup>
                {exchanges.map((ex) => (
                <ListGroup.Item
                    key={ex.exchange_id}
                    active={ex.exchange_name === selectedExchange}
                    onClick={() => onSelectExchange(ex)}
                    style={{ cursor: "pointer" }}
                >
                    {ex.exchange_name}
                </ListGroup.Item>
                ))}
            </ListGroup>
            </div>
        );
    };

    export default ExchangeList;
    ```

    ![exchange mng](/images/projects/mcttool/11-3.png)

### 2.3 AddExchangeModal.tsx

- This modal allows users to add a new exchange.
- It presents a single input for the exchange name and two actions: **Cancel** and **Add**.

    ```tsx
    import { Modal, Button, Form } from "react-bootstrap";

    interface AddExchangeModalProps {
        show: boolean;
        onHide: () => void;
        exchangeName: string;
        onExchangeNameChange: (value: string) => void;
        onAddExchange: () => void;
    }

    const AddExchangeModal = ({
        show,
        onHide,
        exchangeName,
        onExchangeNameChange,
        onAddExchange,
    }: AddExchangeModalProps) => {
        return (
            <Modal show={show} onHide={onHide}>
                <Modal.Header closeButton>
                    <Modal.Title>Add New Exchange</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    <Form>
                        <Form.Group>
                            <Form.Label>Exchange Name</Form.Label>
                            <Form.Control
                                type="text"
                                value={exchangeName}
                                onChange={(e) => onExchangeNameChange(e.target.value)}
                                placeholder="Enter Exchange name"
                            />
                        </Form.Group>
                    </Form>
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="secondary" onClick={onHide}>Cancel</Button>
                    <Button variant="primary" onClick={onAddExchange}>Add</Button>
                </Modal.Footer>
            </Modal>
        );
    };

    export default AddExchangeModal;
    ```

    ![exchange add modal](/images/projects/mcttool/11-2.png)

### 2.4 ApiKeyManager.tsx

- This component sends a POST request to the backend to add API keys.
- It expects an `access_token` to be stored in `localStorage`.
- When the component receives the API key list, it displays it in a table.

    ```tsx
    import { Table, Button, Form } from "react-bootstrap";
    import { useState } from "react";
    import api from "@/services/axios";

    function getUserNoFromToken(): number | null {
        const token = localStorage.getItem("access_token");
        if (!token) return null;

        try {
            const payload = JSON.parse(atob(token.split(".")[1]));
            return payload.user_no || null;
        } catch (err) {
            console.error("Failed to decode JWT:", err);
            return null;
        }
    }

    type ApiKey = {
        public_key_masked: string;
        private_key_masked: string;
        update_date: string;
        is_active: boolean;
    };

    type ApiKeyManagerProps = {
        exchange: { exchange_id: number; exchange_name: string } | null;
        apiKeys: ApiKey[];
        onRefresh: () => void;
    };

    const ApiKeyManager = ({ exchange, apiKeys, onRefresh }: ApiKeyManagerProps) => {
        const [publicKey, setPublicKey] = useState("");
        const [privateKey, setPrivateKey] = useState("");

        const handleAddKey = async () => {
            const userNo = getUserNoFromToken();
            if (!exchange || !userNo || !publicKey || !privateKey) return;
            try {
            await api.post("/api/settings/exchange-api-key", {
                user_no: userNo,
                exchange_id: exchange.exchange_id,
                public_key: publicKey,
                private_key: privateKey
            });
            setPublicKey("");
            setPrivateKey("");
            onRefresh();
            } catch (err) {
            console.error("Failed to add API key:", err);
            }
        };

        return (
            <div>
            <div className="mb-3">
                <h5>{exchange?.exchange_name} API Keys</h5>
                <Form className="d-flex gap-2 mb-2">
                <Form.Control
                    type="text"
                    placeholder="Public Key"
                    value={publicKey}
                    onChange={(e) => setPublicKey(e.target.value)}
                />
                <Form.Control
                    type="password"
                    placeholder="Private Key"
                    value={privateKey}
                    onChange={(e) => setPrivateKey(e.target.value)}
                />
                <Button variant="primary" size="sm" onClick={handleAddKey}>
                    Add
                </Button>
                </Form>
            </div>
            <Table striped bordered hover size="sm">
                <thead>
                <tr>
                    <th>Public Key</th>
                    <th>Private Key</th>
                    <th>Status</th>
                </tr>
                </thead>
                <tbody>
                {apiKeys.map((key, idx) => (
                    <tr key={idx}>
                    <td>{key.public_key_masked}</td>
                    <td>{key.private_key_masked}</td>
                    <td>
                        <span
                        style={{
                            display: "inline-block",
                            width: "10px",
                            height: "10px",
                            borderRadius: "50%",
                            backgroundColor: key.is_active ? "green" : "red"
                        }}
                        ></span>
                    </td>
                    </tr>
                ))}
                </tbody>
            </Table>
            </div>
        );
    };

    export default ApiKeyManager;
    ```

    ![api key mng](/images/projects/mcttool/11-4.png)

### 2.5 DynamicLogTable.tsx

- This component renders a generic table from a list of objects.
- If the list contains date-time fields, it formats them using the `ko-KR` locale and the `Asia/Seoul` timezone.
- Boolean values are shown as **Y**/**N**, and `null`/`undefined` values render as empty cells.

    ```tsx
    import { Table } from "react-bootstrap";

    type DynamicLogTableProps = {
        title: string;
        data: Record<string, unknown>[];
    };

    const DynamicLogTable = ({ title, data }: DynamicLogTableProps) => {
        if (!data || data.length === 0) {
            return <p>No data available.</p>;
        }

        const headers = Object.keys(data[0]);

        return (
            <>
                <h4>{title}</h4>
                <Table striped bordered hover responsive>
                    <thead>
                        <tr>
                            {headers.map((key) => (
                                <th key={key}>{key}</th>
                            ))}
                        </tr>
                    </thead>
                    <tbody>
                        {data.map((item, idx) => (
                            <tr key={idx}>
                                {headers.map((key) => (
                                    <td key={key}>
                                    {item[key] == null
                                        ? ""
                                        : item[key] === true
                                        ? "Y"
                                        : item[key] === false
                                        ? "N"
                                        : typeof item[key] === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.*Z$/.test(item[key] as string)
                                        ? new Intl.DateTimeFormat("ko-KR", {
                                            year: "numeric",
                                            month: "2-digit",
                                            day: "2-digit",
                                            hour: "2-digit",
                                            minute: "2-digit",
                                            second: "2-digit",
                                            hour12: false,
                                            timeZone: "Asia/Seoul",
                                        }).format(new Date(item[key] as string))
                                        : String(item[key])}
                                    </td>
                                ))}
                            </tr>
                        ))}
                    </tbody>
                </Table>
            </>
        );
    };

    export default DynamicLogTable;
    ```

### 2.6 Settings.tsx

- This page renders the **Settings** view.
- **What this page does**
  - Renders the Settings sidebar on the left and the content area on the right.
  - When the **API Keys** tab is active, it loads the exchange list, selects the first exchange by default, and fetches that exchange's API keys.
  - Show two panels side by side: **Exchanges** (left) and **API Keys** (right).
  - Opens a modal to create a new exchange and refreshes the list after creation.
  - For other tabs (to be added later), displays a paginated log table.

    ```tsx
    import { useState, useEffect } from "react";
    import { Container, Row, Col, Pagination } from "react-bootstrap";
    import SettingsSidebar from "@/components/SettingsSideBar";
    import DynamicLogTable from "@/components/DynamicLogTable";
    import api from "@/services/axios";
    import ExchangeList from "@/components/ExchangeList";
    import ApiKeyManager from "@/components/ApiKeyManager";
    import AddExchangeModal from "@/components/AddExchangeModal";

    const Settings = () => {
        const [selectedLog, setSelectedLog] = useState("API Keys");
        interface Exchange {
        exchange_id: number;
        exchange_name: string;
        }

        interface LogEntry {
        [key: string]: string | number | boolean | null;
        }

        const [logDataMap, setLogDataMap] = useState<Record<string, LogEntry[]>>({});
        const [pageMap, setPageMap] = useState<Record<string, number>>({ "API Keys": 1 });
        const itemsPerPage = 10;

        const [exchangeList, setExchangeList] = useState<Exchange[]>([]);
        const [selectedExchange, setSelectedExchange] = useState<Exchange | null>(null);
    
        interface MaskedApiKey {
        public_key_masked: string;
        private_key_masked: string;
        update_date: string;
        is_active: boolean;
        }

    const [apiKeyMap, setApiKeyMap] = useState<Record<string, MaskedApiKey[]>>({});

        const [showExchangeModal, setShowExchangeModal] = useState(false);
        const [newExchangeName, setNewExchangeName] = useState("");

        useEffect(() => {
        if (selectedLog === "API Keys") {
            api.get("/api/settings/exchanges").then((res) => {
            setExchangeList(res.data);
            if (res.data.length > 0) {
                const defaultExchange = res.data[0];
                setSelectedExchange(defaultExchange);
                fetchApiKeys(defaultExchange.exchange_name);
            }
            });
        }
        }, [selectedLog]);

        const fetchApiKeys = (exchange: string) => {
        const token = localStorage.getItem("access_token");
        if (!token) return;

        try {
            const payload = JSON.parse(atob(token.split(".")[1]));
            const user_no = payload.user_no;
            api
            .get(`/api/settings/exchange-api-key`, {
                params: { user_no },
            })
            .then((res) => {
                setApiKeyMap((prev) => ({ ...prev, [exchange]: res.data }));
                console.log(res);
            });
        } catch (e) {
            console.error("Failed to decode token or fetch API keys:", e);
        }
        };

        useEffect(() => {
            if (!logDataMap[selectedLog]) {
            const endpoint = selectedLog === "API Keys" ? "/api/settings/exchanges" : "";
            if (endpoint) {
                api.get(endpoint).then((res) => {
                setLogDataMap((prev) => ({ ...prev, [selectedLog]: res.data }));
                setPageMap((prev) => ({ ...prev, [selectedLog]: 1 }));
                });
            }
            }
        }, [selectedLog, logDataMap]);

        const currentPage = pageMap[selectedLog] || 1;
        const allData = logDataMap[selectedLog] || [];
        const indexOfLastItem = currentPage * itemsPerPage;
        const indexOfFirstItem = indexOfLastItem - itemsPerPage;
        const currentData = allData.slice(indexOfFirstItem, indexOfLastItem);

        const handleAddExchange = async () => {
        if (!newExchangeName.trim()) return;
        try {
            await api.post("/api/settings/exchanges", { exchange_name: newExchangeName });

            const res = await api.get("/api/settings/exchanges");
            setExchangeList(res.data);
            setNewExchangeName("");
            setShowExchangeModal(false);
        } catch (err) {
            console.error("Failed to add exchange: ", err);
        }
        }

        return (
            <Container fluid>
            <Row>
                <Col md={2}>
                <SettingsSidebar selected={selectedLog} onSelect={setSelectedLog} />
                </Col>
                <Col md={10} className="p-4">
                {selectedLog === "API Keys" ? (
                    <Row>
                    <Col md={4}>
                        <ExchangeList
                        exchanges={exchangeList}
                        selectedExchange={selectedExchange?.exchange_name || ""}
                        onSelectExchange={(ex: Exchange) => {
                            setSelectedExchange((ex));
                            fetchApiKeys(ex.exchange_name);
                        }}
                        onAddExchange={() => setShowExchangeModal(true)}
                        />
                    </Col>
                    <Col md={8}>
                        <ApiKeyManager
                        exchange={selectedExchange || { exchange_id: 0, exchange_name: "" }}
                        apiKeys={selectedExchange ? apiKeyMap[selectedExchange.exchange_name] || [] : []}
                        onRefresh={() => {
                            if (selectedExchange) fetchApiKeys(selectedExchange.exchange_name);
                        }}
                        />
                    </Col>
                    </Row>
                ) : (
                    <>
                    <DynamicLogTable title={`${selectedLog} Logs`} data={currentData} />
                    {allData.length > itemsPerPage && (
                        <Pagination className="justify-content-center mt-4">
                        {Array.from({ length: Math.ceil(allData.length / itemsPerPage) }, (_, i) => (
                            <Pagination.Item
                            key={i + 1}
                            active={i + 1 === currentPage}
                            onClick={() =>
                                setPageMap((prev) => ({ ...prev, [selectedLog]: i + 1 }))
                            }
                            >
                            {i + 1}
                            </Pagination.Item>
                        ))}
                        </Pagination>
                    )}
                    </>
                )}
                </Col>
            </Row>
            <AddExchangeModal
            show={showExchangeModal}
            onHide={() => setShowExchangeModal(false)}
            exchangeName={newExchangeName}
            onExchangeNameChange={setNewExchangeName}
            onAddExchange={handleAddExchange}
            />
            </Container>
        );
    };

    export default Settings;
    ```

    ![Settings](/images/projects/mcttool/11-5.png)

## 3. Result

---

![Result](/images/projects/mcttool/11-6.gif)
