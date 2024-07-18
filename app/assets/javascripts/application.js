document.addEventListener('DOMContentLoaded', function() {
  setTimeout(function() {
    var flashMessages = document.querySelectorAll('.flash');
    flashMessages.forEach(function(flashMessage) {
      flashMessage.style.display = 'none';
    });
  }, 5000);
});

