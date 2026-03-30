// Configuration
const API_URL = window.location.hostname === 'localhost' 
    ? 'http://localhost:3000' 
    : 'http://backend:3000';

// DOM Elements
const statusDiv = document.getElementById('status');
const itemsList = document.getElementById('itemsList');
const itemForm = document.getElementById('itemForm');
const itemNameInput = document.getElementById('itemName');
const itemDescriptionInput = document.getElementById('itemDescription');

// Fetch and display backend status
async function fetchStatus() {
    try {
        const response = await fetch(`${API_URL}/health`);
        const data = await response.json();
        
        statusDiv.innerHTML = `
            <p><strong>Status:</strong> ${data.status}</p>
            <p><strong>Architecture:</strong> ${data.architecture}</p>
            <p><strong>Platform:</strong> ${data.platform}</p>
            <p><strong>Last Updated:</strong> ${new Date(data.timestamp).toLocaleString()}</p>
        `;
        statusDiv.className = 'status-card success';
    } catch (error) {
        statusDiv.innerHTML = `
            <p class="error">Failed to connect to backend API</p>
            <p>Error: ${error.message}</p>
        `;
        statusDiv.className = 'status-card error';
    }
}

// Fetch and display items
async function fetchItems() {
    try {
        const response = await fetch(`${API_URL}/api/items`);
        const result = await response.json();
        
        if (result.success && result.data.length > 0) {
            itemsList.innerHTML = result.data.map(item => `
                <div class="item-card">
                    <div class="item-header">
                        <span class="item-name">${escapeHtml(item.name)}</span>
                        <span class="item-id">ID: ${item.id}</span>
                    </div>
                    <p class="item-description">${escapeHtml(item.description || 'No description')}</p>
                    <button class="btn btn-danger" onclick="deleteItem(${item.id})">Delete</button>
                </div>
            `).join('');
        } else {
            itemsList.innerHTML = '<p>No items found. Add one above!</p>';
        }
    } catch (error) {
        itemsList.innerHTML = `<p class="error">Failed to load items: ${error.message}</p>`;
    }
}

// Add new item
async function addItem(event) {
    event.preventDefault();
    
    const name = itemNameInput.value.trim();
    const description = itemDescriptionInput.value.trim();
    
    if (!name) {
        alert('Please enter an item name');
        return;
    }
    
    try {
        const response = await fetch(`${API_URL}/api/items`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ name, description })
        });
        
        const result = await response.json();
        
        if (result.success) {
            itemNameInput.value = '';
            itemDescriptionInput.value = '';
            await fetchItems();
        } else {
            alert('Failed to add item: ' + result.message);
        }
    } catch (error) {
        alert('Error adding item: ' + error.message);
    }
}

// Delete item
async function deleteItem(id) {
    if (!confirm('Are you sure you want to delete this item?')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_URL}/api/items/${id}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (result.success) {
            await fetchItems();
        } else {
            alert('Failed to delete item: ' + result.message);
        }
    } catch (error) {
        alert('Error deleting item: ' + error.message);
    }
}

// Utility function to escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Event listeners
itemForm.addEventListener('submit', addItem);

// Initial load
fetchStatus();
fetchItems();

// Refresh status every 30 seconds
setInterval(fetchStatus, 30000);

// Refresh items every 10 seconds
setInterval(fetchItems, 10000);

// Made with Bob
