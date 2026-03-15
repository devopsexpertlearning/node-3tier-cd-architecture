var express = require('express');
var router = express.Router();
var request = require('request');


var api_url = process.env.API_HOST;

/* GET home page - fetches status + messages from API */
router.get('/', function(req, res, next) {
    // Fetch status (time from DB)
    request({
            method: 'GET',
            url: api_url + '/api/status',
            json: true
        },
        function(error, response, body) {
            var time = 'API Unreachable';
            if (!error && response && response.statusCode === 200 && body && body.length > 0) {
                time = body[0].time;
            }

            // Fetch messages from DB
            request({
                    method: 'GET',
                    url: api_url + '/api/messages',
                    json: true
                },
                function(msgError, msgResponse, msgBody) {
                    var messages = [];
                    if (!msgError && msgResponse && msgResponse.statusCode === 200) {
                        messages = msgBody || [];
                    }
                    res.render('index', {
                        title: '3tier App',
                        time: time,
                        messages: messages
                    });
                }
            );
        }
    );
});

/* POST / - submit a new message via API */
router.post('/', function(req, res, next) {
    var messageText = req.body.message;
    request({
            method: 'POST',
            url: api_url + '/api/messages',
            json: true,
            body: { text: messageText }
        },
        function(error, response, body) {
            // Redirect back to homepage after posting
            res.redirect('/');
        }
    );
});

module.exports = router;