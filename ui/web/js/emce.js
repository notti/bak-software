!function ($) {
    $(function(){
        if (! ("WebSocket" in window)) WebSocket = MozWebSocket;
        ws = new WebSocket("ws://"+location.hostname+":8080");
        ws.onmessage = function(e) {
            var m = JSON.parse(e.data);
            var msg = e.data, color = 'red';
            switch(m.cmd) {
                case 'update':
                case 'set': msg = m.target + ' = ' + m.value; color = 'green'; 
                            setValue(m.target, m.value); break;
                case 'do': msg = m.target + ' started'; color = 'yellow';
                           if (m.target == 'trigger/arm') { query('trigger/arm'); }
                           break;
                case 'int': msg = m.target + ' <i class="icon-fire"></i>'; color = 'magenta'; 
                    switch(m.target) {
                        case 'avg_done': query('average/err'); break;
                        case 'rec0_invalid': case 'rec0_valid': query('gtx0/data_valid'); break;
                        case 'rec1_invalid': case 'rec1_valid': query('gtx1/data_valid'); break;
                        case 'stream_invalid': case 'stream_valid': query('receiver/stream_valid'); break;
                        case 'core_done': query('core/ov_ifft'); query('core/ov_fft'); query('core/ov_cmul'); break;
                        case 'trigd': query('trigger/arm'); break;
                        case 'tx_ovfl': query('transmitter/ovfl'); break;
                    }
                    break;
            }
            log('<i class="icon-arrow-left"></i> ' + msg, color);
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
            var d = new Date();
            var hh = d.getHours(), mm = d.getMinutes(), ss = d.getSeconds(), ms = d.getMilliseconds();
            hh = ('0'+hh).substr(-2,2);
            mm = ('0'+mm).substr(-2,2);
            ss = ('0'+ss).substr(-2,2);
            ms = ('00'+ms).substr(-3,3);
            $('#log.console').append('<span style="color: '+color+';">['+hh+':'+mm+':'+ss+'.'+ms+'] '+line+'</span></br>');
            $('#log.console')[0].scrollTop = $('#log.console')[0].scrollHeight;
        }

        function clearLog() {
            $('#log.console').text('');
        }

        function query(target) {
            ws.send(JSON.stringify({cmd:'get', target:target}));
        }

        function sendValue(target, value) {
            var line = '<i class="icon-arrow-right"></i> ' + target;
            if (value) {
                line+=' = ' + value;
                ws.send(JSON.stringify({cmd:'set', target:target, value:value}))
            } else {
                ws.send(JSON.stringify({cmd:'do', target:target}))
            }
            log(line, 'blue');
        }

        function checkInput(element, value) {
            var ok = true;
            if (!isFinite(value) || value == '') {
                ok = false;
            } else {
                var value = parseInt(value);
                var min = parseInt(element.attr('min'));
                var max = parseInt(element.attr('max'));
                if (value < min || value > max || isNaN(value)) {
                    ok = false;
                }
            }
            if (ok) {
                element.parent().parent().removeClass('error').addClass('success');
            } else {
                element.parent().parent().removeClass('success').addClass('error');
            }
            return ok;
        }

        function setValue(target, value) {
            var tmp = target.split('/');
            var filter = '#'+tmp[0];
            var element;
            var st;
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
                        }
                        break;
                    case 'type':
                        switch(value) {
                            case '0': value = 'Int'; break;
                            case '1': value = 'Ext'; break;
                        }
                        break;
                    case 'rxeqmix':
                        switch(value) {
                            case '0': value = '00'; break;
                            case '1': value = '01'; break;
                            case '2': value = '10'; break;
                            case '3': value = '11'; break;
                        }
                        break;
                    case 'shift':
                    case 'scale_cmul':
                        switch(value) {
                            case '0': value = '16'; break;
                            case '1': value = '15'; break;
                            case '2': value = '14'; break;
                            case '3': value = '13'; break;
                        }
                        break;
                }
                element.text(value);
            } else if ((element = $(filter)).length) { 
                if (element.is('a')) { //button
                    if (tmp[1] == 'arm') {
                        if (parseInt(value)) {
                            element.addClass('btn-warning disabled');
                        } else {
                            element.removeClass('btn-warning disabled');
                        }
                    } else if (element.hasClass('toggle')) { //toggle button
                        if (parseInt(value))
                            element.addClass('active');
                        else
                            element.removeClass('active');
                    } else if ((st = element.attr('status')) != undefined) { //status button
                        if (parseInt(value) == st) {
                            element.removeClass('btn-danger');
                            element.addClass('btn-success');
                            element.html('<i class="icon-ok"></i>');
                        } else {
                            element.removeClass('btn-success');
                            element.addClass('btn-danger');
                            element.html('<i class="icon-remove"></i>');
                        }
                    }
                } else if (element.is('input')) { //text
                    values[target] = value;
                    element.attr('value', value);
                    checkInput(element, value);
                } else {
                    console.log('unknown', target, value);
                }
            } else {
                console.log('unknown', target, value);
            }
        }

        $(':file').filestyle({icon: true, textField: false, buttonText: '', classButton: 'btn btn-small', classIcon: 'icon-arrow-up'}).change(function(e) {
            var element = $(this).parent();
            var formData = new FormData();
            var url = '/data/' + element.attr('id');
            var type = element.attr('desc');
            var name = this.files[0].name;
            formData.append('data', this.files[0]);
            $.ajax({
                url: url,
                type: 'POST',
                beforeSend: function (jqXHR, settings) { log(name + ' <i class="icon-arrow-right"></i> '  + type, 'blue'); },
                success: function (data, textStatus, jqXHR) { log(name + ' uploaded.', 'green'); } ,
                error: function (jqXHR, textStatus, errorThrown) { log(name + ' failed: ' + textStatus, 'red'); },
                data: formData,
                cache: false,
                contentType: false,
                processData: false
            });
            element[0].reset();
        });
        $('a').attr('tabindex', -1);
        $('a[rel=tooltip]').tooltip();
        $('.frame:has(.frame)').addClass('parent-frame');
        $('.btn:not(.disabled):not(.dropdown-toggle):not(.link):not(button)').click(function(e) {
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
        $('.btn#ovfl').click(function(e) {
            setValue('transmitter/ovfl', '0');
            sendValue('transmitter/ovfl', '0');
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
            if (checkInput(element, value)) {
                values[attribute] = value;
                sendValue(attribute, value);
            }
        });
        $('input').keydown(function(e) {
            if (e.which == 27) {
                var element = $(this);
                var attribute = elementToAttribute(element);
                $(this).attr('value', values[attribute]);
                checkInput(element, values[attribute]);
            }
        });
        $('input').keypress(function(e) {
            if (e.which == 13) {
                var element = $(this);
                var attribute = elementToAttribute(element);
                var value = element.attr('value');
                if (checkInput(element, value)) {
                    values[attribute] = value;
                    sendValue(attribute, value);
                }
                e.preventDefault();
            }
        });
    });
}(window.jQuery);
