var express = require('express');
var router = express.Router();

var api_url = process.env.API_HOST;

/* GET home page - fetches status + messages from API */
router.get('/', function(req, res, next) {
    Promise.all([
        fetch(api_url + '/api/status').then(function(r) { return r.json(); }).catch(function() { return []; }),
        fetch(api_url + '/api/messages').then(function(r) { return r.json(); }).catch(function() { return []; })
    ]).then(function(results) {
        var statusBody = results[0];
        var messages = results[1];
        var time = 'API Unreachable';
        if (statusBody && statusBody.length > 0) {
            time = statusBody[0].time;
        }
        res.render('index', {
            title: '3tier App',
            time: time,
            messages: Array.isArray(messages) ? messages : []
        });
    }).catch(function(err) {
        next(err);
    });
});

/* POST / - submit a new message via API */
router.post('/', function(req, res, next) {
    fetch(api_url + '/api/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: req.body.message })
    }).then(function() {
        res.redirect('/');
    }).catch(function() {
        res.redirect('/');
    });
});

module.exports = router;