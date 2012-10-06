!function ($) {
    $(function(){
        $('a[rel=tooltip]').tooltip();
        $('.frame:has(.frame)').addClass('parent-frame');
    });
}(window.jQuery);
