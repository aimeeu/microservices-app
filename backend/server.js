const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// In-memory data store
let items = [
  { id: 1, name: 'Item 1', description: 'First item' },
  { id: 2, name: 'Item 2', description: 'Second item' },
  { id: 3, name: 'Item 3', description: 'Third item' }
];

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    architecture: process.arch,
    platform: process.platform
  });
});

// Get all items
app.get('/api/items', (req, res) => {
  res.json({
    success: true,
    data: items,
    count: items.length
  });
});

// Get single item
app.get('/api/items/:id', (req, res) => {
  const item = items.find(i => i.id === parseInt(req.params.id));
  if (!item) {
    return res.status(404).json({ success: false, message: 'Item not found' });
  }
  res.json({ success: true, data: item });
});

// Create new item
app.post('/api/items', (req, res) => {
  const { name, description } = req.body;
  if (!name) {
    return res.status(400).json({ success: false, message: 'Name is required' });
  }
  
  const newItem = {
    id: items.length > 0 ? Math.max(...items.map(i => i.id)) + 1 : 1,
    name,
    description: description || ''
  };
  
  items.push(newItem);
  res.status(201).json({ success: true, data: newItem });
});

// Update item
app.put('/api/items/:id', (req, res) => {
  const item = items.find(i => i.id === parseInt(req.params.id));
  if (!item) {
    return res.status(404).json({ success: false, message: 'Item not found' });
  }
  
  const { name, description } = req.body;
  if (name) item.name = name;
  if (description !== undefined) item.description = description;
  
  res.json({ success: true, data: item });
});

// Delete item
app.delete('/api/items/:id', (req, res) => {
  const index = items.findIndex(i => i.id === parseInt(req.params.id));
  if (index === -1) {
    return res.status(404).json({ success: false, message: 'Item not found' });
  }
  
  items.splice(index, 1);
  res.json({ success: true, message: 'Item deleted' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend API running on port ${PORT}`);
  console.log(`Architecture: ${process.arch}`);
  console.log(`Platform: ${process.platform}`);
  console.log(`Node version: ${process.version}`);
});

// Made with Bob
