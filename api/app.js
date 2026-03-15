var express = require('express');
var app = express();
var uuid = require('node-uuid');
var bodyParser = require('body-parser');

// Parse JSON request bodies
app.use(bodyParser.json());

var pg = require('pg');
const conString = {
    user: process.env.DBUSER,
    database: process.env.DB,
    password: process.env.DBPASS,
    host: process.env.DBHOST,
    port: process.env.DBPORT,
    ssl: process.env.DBSSL === 'true' ? { rejectUnauthorized: false } : false
};

// Routes

// GET /api/status - Health check: returns current DB time
app.get('/api/status', function(req, res) {
  const Pool = require('pg').Pool
  const pool = new Pool(conString)
  pool.connect((err, client, release) => {
    if (err) {
      console.error('Error acquiring client', err.stack);
      return res.status(500).send([{ error: 'Error acquiring client' }]);
    }
    client.query('SELECT now() as time', (err, result) => {
      release();
      if (err) {
        console.error('Error executing query', err.stack);
        return res.status(500).send([{ error: 'Error executing query' }]);
      }
      res.status(200).send(result.rows);
    });
  });
  pool.end()
});

// GET /api/messages - Read all messages from DB
app.get('/api/messages', function(req, res) {
  const Pool = require('pg').Pool;
  const pool = new Pool(conString);
  pool.connect((err, client, release) => {
    if (err) {
      console.error('Error acquiring client', err.stack);
      return res.status(500).json({ error: 'Database connection failed' });
    }
    client.query('SELECT * FROM messages ORDER BY created_at DESC', (err, result) => {
      release();
      if (err) {
        console.error('Error executing query', err.stack);
        return res.status(500).json({ error: 'Query failed' });
      }
      res.status(200).json(result.rows);
    });
  });
  pool.end();
});

// POST /api/messages - Write a new message to DB
app.post('/api/messages', function(req, res) {
  var text = req.body.text;
  if (!text || text.trim() === '') {
    return res.status(400).json({ error: 'Message text is required' });
  }
  const Pool = require('pg').Pool;
  const pool = new Pool(conString);
  pool.connect((err, client, release) => {
    if (err) {
      console.error('Error acquiring client', err.stack);
      return res.status(500).json({ error: 'Database connection failed' });
    }
    client.query('INSERT INTO messages (text) VALUES ($1) RETURNING *', [text.trim()], (err, result) => {
      release();
      if (err) {
        console.error('Error executing query', err.stack);
        return res.status(500).json({ error: 'Insert failed' });
      }
      res.status(201).json(result.rows[0]);
    });
  });
  pool.end();
});

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  var err = new Error('Not Found');
  err.status = 404;
  next(err);
});

// error handlers

// development error handler
// will print stacktrace
if (app.get('env') === 'development') {
  app.use(function(err, req, res, next) {
    res.status(err.status || 500);
    res.json({
      message: err.message,
      error: err
    });
  });
}

// production error handler
// no stacktraces leaked to user
app.use(function(err, req, res, next) {
  res.status(err.status || 500);
  res.json({
    message: err.message,
    error: {}
  });
});


module.exports = app;
