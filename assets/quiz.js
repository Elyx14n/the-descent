(function () {
  'use strict';
  document.querySelectorAll('[data-quiz]').forEach(function (quiz) {
    const feedback = quiz.querySelector('[role=status]');
    quiz.addEventListener('change', function (event) {
      if (event.target.type !== 'radio') return;
      const correct = event.target.value === quiz.dataset.answer;
      feedback.dataset.correct = String(correct);
      feedback.textContent = (correct ? 'Yes. ' : 'Revisit the relationship. ') +
        (correct ? quiz.dataset.explanation : quiz.dataset.hint);
    });
  });
}());
