!function ($) {
    $(function(){
        // store old values 
        function sendValue(target, value) {
            console.log(target, value);
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
            var attribute = '';
            var p = element.parents().map(function(k,v) { return v.id; }).filter(function(k,v) { return v;});
            var value = undefined;
            if (p.length)
                attribute = p[0] + '/';
            attribute += element.attr('id');
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
            var attribute = '';
            var p = element.parents().map(function(k,v) { return v.id; }).filter(function(k,v) { return v;});
            var value = element.val();
            if (p.length)
                attribute = p[0] + '/';
            attribute += element.attr('id');
            console.log('check input');
            sendValue(attribute, value);
        });
        $('input').on('input', function(e) {
            console.log('check input');
        });
        $('input').keydown(function(e) {
            if(e.keyCode == 27) {
                console.log('esc');
                // restore old
            }
        });
    });
}(window.jQuery);
