!function ($) {
    $(function(){
        // store old values 
        // clear log
        // append log
        /*var b = new Blob([JSON.stringify({a: 1})],{type: "text\/json"});
        var url = window.URL.createObjectURL(b); */

        if (! ("WebSocket" in window)) WebSocket = MozWebSocket;
        ws = new WebSocket("ws://"+location.hostname+":8080");
        ws.onmessage = function(e) {
            var m = JSON.parse(e.data);
            console.log(m);
        };
        ws.onerror = function(e) {
            console.log(e);
        }

        var values = {};

        function elementToAttribute(element) {
            var attribute = '';
            var p = element.parents().map(function(k,v) { return v.id; }).filter(function(k,v) { return v;});
            if (p.length)
                attribute = p[0] + '/';
            attribute += element.attr('id');
            return attribute;
        }

        function log(line, color) {
            $('#log.console').append('<span style="color: '+color+';">'+line+'</span></br>').scrollTop(10000);
        }

        function clearLog() {
            $('#log.console').text('');
        }

        function sendValue(target, value) {
            var line = '> ' + target;
            if (value)
                line+=' -> ' + value;
            log(line, 'blue');
        }

        function setValue(target, value) {
            var tmp = target.split('/');
            var filter = '#'+tmp[0];
            var element;
            if (tmp.length == 2) // aka a/b
                filter += ' #' + tmp[1];
            element = $(filter + ' .value');
            if (element.length) { // dropdown
                switch(tmp[1]) {
                    case 'width':
                        switch(value) {
                            case '0': value = 'Off'; break;
                            case '1': value = '2x'; break;
                            case '2': value = '4x'; break;
                            case '3': value = '8x'; break;
                        }
                        break;
                    case 'input_select':
                        switch(value) {
                            case '0': value = 'gtx0'; break;
                            case '1': value = 'gtx1'; break;
                            case '2': value = 'gtx2'; break;
                        }
                        break;
                }
                element.text(value);
            } else if ((element = $(filter)).length) { 
                if (element.is('a')) { //button
                    if (element.hasClass('toggle')) { //toggle button
                        if (parseInt(value))
                            element.addClass('active');
                        else
                            element.removeClass('active');
                    }
                } else if (element.is('input')) { //text
                    values[target] = value;
                    element.attr('value', value);
                } else {
                    console.log('unknown', target, value);
                }
            } else {
                console.log('unknown', target, value);
            }
        }

        $('a[rel=tooltip]').tooltip();
        $('.frame:has(.frame)').addClass('parent-frame');
        $('.btn:not(.disabled):not(.dropdown-toggle)').click(function(e) {
            var element = $(this);
            var attribute = elementToAttribute(element);
            var value = undefined;

            if (attribute == 'log/rst') {
                clearLog();
                e.preventDefault();
                return;
            }
            if (element.hasClass('toggle'))
                if (element.hasClass('active'))
                    value = '0';
                else
                    value = '1';
            
            sendValue(attribute, value);
            setValue(attribute, value);
            e.preventDefault();
        });
        $('.dropdown-menu a').click(function(e) {
            var element = $(this);
            var p = element.parents().map(function(k,v) { return v.id; }).filter(function(k,v) { return v;});
            var attribute = p[1] + '/' + p[0];
            var value = element.attr('id');

            sendValue(attribute, value);
            setValue(attribute, value);
            e.preventDefault();
        });
        $('input').change(function(e) {
            var element = $(this);
            var attribute = elementToAttribute(element);
            var value = element.attr('value');
            //check input
            values[attribute] = value;
            sendValue(attribute, value);
        });
        $('input').on('input', function(e) {
            //check input
        });
        $('input').keydown(function(e) {
            if(e.keyCode == 27) {
                var element = $(this);
                var attribute = elementToAttribute(element);
                $(this).attr('value',values[attribute]);
            }
        });
    });
}(window.jQuery);
